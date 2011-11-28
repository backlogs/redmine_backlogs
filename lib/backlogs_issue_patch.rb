require_dependency 'issue'

module Backlogs
  module IssuePatch
    def self.included(base) # :nodoc:
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)

      base.class_eval do
        unloadable

        alias_method_chain :move_to_project_without_transaction, :autolink

        before_save :backlogs_before_save
        after_save  :backlogs_after_save
      end
    end

    module ClassMethods
    end

    module InstanceMethods
      def move_to_project_without_transaction_with_autolink(new_project, new_tracker = nil, options = {})
        newissue = move_to_project_without_transaction_without_autolink(new_project, new_tracker, options)
        return newissue if newissue.blank? || !self.project.module_enabled?('backlogs')

        if project_id == newissue.project_id and is_story? and newissue.is_story? and id != newissue.id
          relation = IssueRelation.new :relation_type => IssueRelation::TYPE_DUPLICATES
          relation.issue_from = self
          relation.issue_to = newissue
          relation.save
        end

        return newissue
      end

      def journalized_update_attributes!(attribs)
        init_journal(User.current)
        @issue_before_change.position = position
        return update_attributes!(attribs)
      end

      def journalized_update_attributes(attribs)
        init_journal(User.current)
        @issue_before_change.position = position
        return update_attributes(attribs)
      end

      def journalized_update_attribute(attrib, v)
        init_journal(User.current)
        @issue_before_change.position = position
        update_attribute(attrib, v)
      end

      def is_story?
        return RbStory.trackers.include?(tracker_id)
      end

      def is_task?
        return (tracker_id == RbTask.tracker)
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
            @rb_story = Issue.find(:first, :order => 'lft DESC', :conditions => [ "root_id = ? and lft < ? and tracker_id in (?)", root_id, lft, RbStory.trackers ])
            @rb_story = @rb_story.becomes(RbStory) if @rb_story
          end
        end
        return @rb_story
      end

      def blocks
        # return issues that I block that aren't closed
        return [] if closed?
        relations_from.collect {|ir| ir.relation_type == 'blocks' && !ir.issue_to.closed? ? ir.issue_to : nil}.compact
      end

      def blockers
        # return issues that block me
        return [] if closed?
        relations_to.collect {|ir| ir.relation_type == 'blocks' && !ir.issue_from.closed? ? ir.issue_from : nil}.compact
      end

      def velocity_based_estimate
        return nil if !self.is_story? || ! self.story_points || self.story_points <= 0

        hpp = self.project.scrum_statistics.hours_per_point
        return nil if ! hpp

        return Integer(self.story_points * (hpp / 8))
      end

      def backlogs_before_save
        if project.module_enabled?('backlogs') && (self.is_task? || self.story)
          self.remaining_hours ||= self.estimated_hours
          self.estimated_hours ||= self.remaining_hours

          self.remaining_hours = 0 if self.status.backlog_is?(:success)

          self.position = nil
          self.fixed_version_id = self.story.fixed_version_id if self.story
          self.tracker_id = RbTask.tracker
        elsif self.is_story?
          self.remaining_hours = self.leaves.sum("COALESCE(remaining_hours, 0)").to_f
        end

        @issue_before_change.position = self.position if @issue_before_change # don't log position updates

        return true
      end

      def backlogs_after_save
        ## automatically sets the tracker to the task tracker for
        ## any descendant of story, and follow the version_id
        ## Normally one of the _before_save hooks ought to take
        ## care of this, but appearantly neither root_id nor
        ## parent_id are set at that point

        return unless self.project.module_enabled? 'backlogs'

        if self.is_story?
          # raw sql and manual journal here because not
          # doing so causes an update loop when Issue calls
          # update_parent :<
          Issue.find(:all, :conditions => ["root_id=? and lft>? and rgt<? and fixed_version_id<>?
                                            and exists(select 1 from journals j join journal_details jd on j.id = jd.journal_id
                                                           where j.journalized_id = issues.id and j.journalized_type = 'Issue'
                                                           and jd.property='attr' and jd.prop_key='fixed_version_id')", root_id, lft, rgt, fixed_version_id]).each{ |task|
            j = Journal.new
            j.journalized = task
            j.created_on = Time.now
            j.user = User.current
            j.details << JournalDetail.new(:property => 'attr', :prop_key => 'fixed_version_id', :old_value => task.fixed_version_id, :value => fixed_version_id)
            j.save!
          }
          connection.execute("update issues set tracker_id = #{RbTask.tracker}, fixed_version_id = #{connection.quote(fixed_version_id)} where root_id = #{self.root_id} and lft > #{self.lft} and rgt < #{self.rgt}")

          # safe to do by sql since we don't want any of this logged
          unless self.position
            max = 0
            connection.execute('select max(position) from issues where not position is null').each {|i| max = i[0] }
            connection.execute("update issues set position = #{connection.quote(max)} + 1 where id = #{id}")
          end
        end

        if self.story || self.is_task?
          connection.execute("update issues set tracker_id = #{RbTask.tracker} where root_id = #{self.root_id} and lft >= #{self.lft} and rgt <= #{self.rgt}")
        end
      end

      def value_at(property, time)
        return history(property, [time.to_date])[0]
      end

      def history(property, days)
        created_day = created_on.to_date
        active_days = days.select{|d| d >= created_day}

        # if not active, don't do anything
        return [nil] * (days.size + 1) if active_days.size == 0

        # anything before the creation date is nil
        prefix = [nil] * (days.size - active_days.size)

        # add one extra day as end-of-last-day
        active_days << (active_days[-1] + 1)

        values = [nil] * active_days.size

        journals = false
        JournalDetail.find(:all, :order => "journals.created_on asc" , :joins => :journal,
                                 :conditions => ["property = 'attr' and prop_key = '#{property}'
                                                  and journalized_type = 'Issue' and journalized_id = ?",
                                                  id]).each {|detail|
          # if this is the first journal, fill up with initial old_value
          values.fill(detail.old_value) unless values[0]

          # get the date from which this value is current up to now, and fill the remainder (might be overwritten later)
          jdate = detail.journal.created_on.to_date
          if jdate < active_days[0]
            i = 0
          else
            i = active_days.index{|d| d > jdate}
          end

          journals = true
          values.fill(detail.value, i) if i
        }

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
        @@backlogs_column_type[property] ||= Issue.connection.columns(Issue.table_name).select{|c| c.name == "#{property}"}.collect{|c| c.type}[0]

        return values.collect{|v|
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
        }
      end
    end
  end
end

Issue.send(:include, Backlogs::IssuePatch) unless Issue.included_modules.include? Backlogs::IssuePatch
