require_dependency 'issue'

module Backlogs
  module IssuePatch
    def self.included(base) # :nodoc:
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)

      base.class_eval do
        unloadable

        before_save   :backlogs_before_save
        after_save    :backlogs_after_save
        after_destroy :backlogs_after_destroy
      end
    end

    module ClassMethods
    end

    module InstanceMethods
      def journalized_update_attributes!(attribs)
        init_journal(User.current)
        self.becomes(Issue).update_attributes!(attribs)
      end

      def journalized_update_attributes(attribs)
        init_journal(User.current)
        self.becomes(Issue).update_attributes(attribs)
      end

      def journalized_update_attribute(attrib, v)
        init_journal(User.current)
        self.becomes(Issue).update_attribute(attrib, v)
      end

      def is_story?
        RbStory.trackers.include?(tracker_id)
      end

      def is_task?
        tracker_id == RbTask.tracker
      end

      def story
        if @rb_story.nil?
          if self.new_record?
            parent_id = self.parent_id
            parent_id = self.parent_issue_id if parent_id.blank?
            parent_id = nil if parent_id.blank?
            parent = parent_id ? Issue.find(parent_id) : nil

            if parent.nil?
              @rb_story = nil
            elsif parent.is_story?
              @rb_story = parent.becomes(RbStory)
            else
              @rb_story = parent.story
            end
          else
            @rb_story = Issue.find(:first, :order => 'lft DESC', :conditions => ["root_id = ? AND lft < ? AND rgt > ? AND tracker_id IN (?)", root_id, lft, rgt, RbStory.trackers])
            @rb_story = @rb_story.becomes(RbStory) if @rb_story
          end
        end
        @rb_story
      end

      def blocks
        # return issues that I block that aren't closed
        return [] if closed?
        begin
          return relations_from.collect { |ir| ir.relation_type == 'blocks' && !ir.issue_to.closed? ? ir.issue_to : nil }.compact
        rescue
          # stupid rails and their ignorance of proper relational databases
          RAILS_DEFAULT_LOGGER.error "Cannot return the blocks list for #{self.id}: #{e}"
          return []
        end
      end

      def blockers
        # return issues that block me
        return [] if closed?
        relations_to.collect { |ir| ir.relation_type == 'blocks' && !ir.issue_from.closed? ? ir.issue_from : nil }.compact
      end

      def velocity_based_estimate
        return nil if !self.is_story? || ! self.story_points || self.story_points <= 0

        hpp = self.project.scrum_statistics.hours_per_point
        return nil if ! hpp

        Integer(self.story_points * (hpp / 8))
      end

      def backlogs_before_save
        if Backlogs.configured?(project) && (self.is_task? || self.story)
          self.remaining_hours ||= self.estimated_hours
          self.estimated_hours ||= self.remaining_hours

          self.remaining_hours = 0 if self.status.backlog_is?(:success)

          self.position = nil
          self.fixed_version_id = self.story.fixed_version_id if self.story
          self.tracker_id = RbTask.tracker
          self.start_date = Date.today if self.start_date.nil? && self.status_id != IssueStatus.default.id
        elsif self.is_story?
          self.remaining_hours = self.leaves.sum("COALESCE(remaining_hours, 0)").to_f
        end

        true
      end

      def backlogs_after_save
        ## automatically sets the tracker to the task tracker for
        ## any descendant of story, and follow the version_id
        ## Normally one of the _before_save hooks ought to take
        ## care of this, but appearantly neither root_id nor
        ## parent_id are set at that point

        return unless Backlogs.configured?(self.project)

        if self.is_story?
          # raw sql and manual journal here because not
          # doing so causes an update loop when Issue calls
          # update_parent :<
          Issue.find(:all, :conditions => ["root_id = ? AND lft > ? AND rgt < ? AND
                                          (
                                            (? IS NULL AND NOT fixed_version_id IS NULL)
                                            OR
                                            (NOT ? IS NULL AND fixed_version_id IS NULL)
                                            OR
                                            (NOT ? IS NULL AND NOT fixed_version_id IS NULL AND ? <> fixed_version_id)
                                          )", root_id, lft, rgt, fixed_version_id, fixed_version_id, fixed_version_id, fixed_version_id]).each{|task|
            j = Journal.new
            j.journalized = task
            case Backlogs.platform
            when :redmine
              j.created_on = Time.now
            when :chiliproject
              j.created_at = Time.now
            end
            j.user = User.current
            j.details << JournalDetail.new(:property => 'attr', :prop_key => 'fixed_version_id', :old_value => task.fixed_version_id, :value => fixed_version_id)
            j.save!
          }
          connection.execute("UPDATE issues SET tracker_id = #{RbTask.tracker}, fixed_version_id = #{connection.quote(fixed_version_id)} WHERE root_id = #{self.root_id} AND lft > #{self.lft} AND rgt < #{self.rgt}")

          # safe to do by sql since we don't want any of this logged
          unless self.position
            max = 0
            connection.execute('SELECT COALESCE(MAX(position), -1) + 1 FROM issues WHERE NOT position IS NULL').each { |i| max = i[0] }
            connection.execute("UPDATE issues SET position = #{connection.quote(max)} WHERE id = #{id}")
          end
        end

        if self.story || self.is_task?
          connection.execute("UPDATE issues SET tracker_id = #{RbTask.tracker} WHERE root_id = #{self.root_id} AND lft >= #{self.lft} AND rgt <= #{self.rgt}")
        end
      end

      def backlogs_after_destroy
        return if self.position.nil?
        Issue.connection.execute("UPDATE issues SET position = position - 1 WHERE position > #{self.position}")
      end

      def value_at(property, time)
        history(property, [time.to_date])[0]
      end

      def history(property, days)
        created_day = created_on.to_date
        active_days = days.select { |d| d >= created_day }

        # if not active, don't do anything
        return [nil] * (days.size + 1) if active_days.size == 0

        # anything before the creation date is nil
        prefix = [nil] * (days.size - active_days.size)

        # add one extra day as end-of-last-day
        active_days << (active_days[-1] + 1)

        values = [nil] * active_days.size

        property_s = property.to_s
        case Backlogs.platform
        when :redmine
          changes = JournalDetail.find(:all,
                                       :conditions => ["property = 'attr' AND prop_key = '#{property}'
                                                        AND journalized_type = 'Issue' AND journalized_id = ?", id],
                                       :order => "journals.created_on ASC",
                                       :joins => :journal).collect do |detail|
            [detail.journal.created_on.to_date, detail.old_value, detail.value]
          end
        when :chiliproject
          # the chiliproject changelog is screwed up beyond all reckoning...
          # a truly horrid journals design -- worse than RMs, and that takes some doing
          # I know this should be using activerecord introspection, but someone else will have to go
          # rummaging through the docs for self.class.reflect_on_association et al.
          table = case property
                  when :status_id then 'issue_statuses'
                  else nil
                  end

          valid_ids = table ? RbStory.connection.select_values("SELECT id FROM #{table}").collect { |x| x.to_i } : nil
          changes = self.journals.reject { |j| j.created_at < self.created_on || j.changes[property_s].nil? }.collect { |j|
            delta = valid_ids ? j.changes[property_s].collect { |v| valid_ids.include?(v) ? v : nil } : j.changes[property_s]
            [j.created_at.to_date] + delta
          }
        end

        journals = false
        changes.each do |change|
          date, before, after = *change

          # if this is the first journal, fill up with initial old_value
          values.fill(before) unless values[0]

          # get the date from which this value is current up to now, and fill the remainder (might be overwritten later)
          if date < active_days[0]
            i = 0
          else
            i = active_days.index { |d| d > date }
          end

          journals = true
          values.fill(after, i) if i
        end

        # if no journals was found, the current value is what all the days have
        if journals
          values[-1] = send(property)
        else
          # otherwise, just set the last day to whatever the current value is.
          # I _know_ this isn't entirely right, and could just be skipped and it would be the real truth,
          # but fact of the matter is people don't update the stories/tasks exactly on the last day of the sprint;
          # often, it happens just after. This makes the burndown look OK. You shouldn't be re-using tasks/stories
          # over sprints anyhow.
          values.fill(send(property))
        end

        # ignore the start-of-day value for issues created mid-sprint
        values[0] = nil if created_day > days[0]

        values = prefix + values

        # and convert to the proper type (the journal holds only strings)

        @@backlogs_column_type ||= {}
        @@backlogs_column_type[property] ||= Issue.connection.columns(Issue.table_name).select { |c| c.name == "#{property}" }.collect { |c| c.type }[0]

        return values.collect do |v|
          if v.nil?
            v
          else
            case @@backlogs_column_type[property]
            when :integer
              v.blank? ? nil : Integer(v)
            when :float
              v.blank? ? nil : Float(v)
            when :string
              v.to_s
            else
              raise "Unexpected field type '#{@@backlogs_column_type[property].inspect}' for Issue##{property}"
            end
          end
        end
      end
    end
  end
end

Issue.send(:include, Backlogs::IssuePatch) unless Issue.included_modules.include? Backlogs::IssuePatch
