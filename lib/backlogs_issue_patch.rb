require_dependency 'issue'

module Backlogs
  module IssuePatch
    def self.included(base) # :nodoc:
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)

      base.class_eval do
        unloadable

        acts_as_list_with_gaps :default => (Backlogs.setting[:new_story_position] == 'bottom' ? 'bottom' : 'top')

        safe_attributes 'position'
        before_save :backlogs_before_save
        after_save  :backlogs_after_save

        include Backlogs::ActiveRecord::Attributes
      end
    end

    module ClassMethods
    end

    module InstanceMethods
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
            @rb_story = Issue.find(:first, :order => 'lft DESC', :conditions => [ "root_id = ? and lft < ? and rgt > ? and tracker_id in (?)", root_id, lft, rgt, RbStory.trackers ])
            @rb_story = @rb_story.becomes(RbStory) if @rb_story
          end
        end
        return @rb_story
      end

      def blocks
        # return issues that I block that aren't closed
        return [] if closed?
        begin
          return relations_from.collect {|ir| ir.relation_type == 'blocks' && !ir.issue_to.closed? ? ir.issue_to : nil }.compact
        rescue
          # stupid rails and their ignorance of proper relational databases
          Rails.logger.error "Cannot return the blocks list for #{self.id}: #{e}"
          return []
        end
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
        if Backlogs.configured?(project) && (self.is_task? || self.story)
          self.remaining_hours = self.estimated_hours if self.remaining_hours.blank?
          self.estimated_hours = self.remaining_hours if self.estimated_hours.blank?

          self.remaining_hours = 0 if self.status.backlog_is?(:success)

          self.fixed_version = self.story.fixed_version if self.story
          self.start_date = Date.today if self.start_date.blank? && self.status_id != IssueStatus.default.id

          self.tracker = Tracker.find(RbTask.tracker) unless self.tracker_id == RbTask.tracker
        elsif self.is_story?
          self.remaining_hours = self.leaves.sum("COALESCE(remaining_hours, 0)").to_f
          if self.fixed_version
            self.start_date ||= (self.fixed_version.sprint_start_date || Date.today)
            self.due_date = self.fixed_version.effective_date || Date.today
            self.due_date = self.start_date if self.due_date < self.start_date if self.due_date
          else
            self.start_date = nil
            self.due_date = nil
          end
        end

        self.move_to_top if self.position.blank? || (@copied_from.present? && @copied_from.position == self.position)

        # scrub position from the journal by copying the new value to the old
        @attributes_before_change['position'] = self.position if @attributes_before_change

        @backlogs_new_record = self.new_record?

        return true
      end

      def backlogs_after_save
        RbJournal.rebuild(self) if @backlogs_new_record

        return unless Backlogs.configured?(self.project)

        if self.is_story?
          # raw sql and manual journal here because not
          # doing so causes an update loop when Issue calls
          # update_parent :<
          tasks_updated = []
          Issue.find(:all, :conditions => ["root_id=? and lft>? and rgt<? and
                                          (
                                            (? is NULL and not fixed_version_id is NULL)
                                            or
                                            (not ? is NULL and fixed_version_id is NULL)
                                            or
                                            (not ? is NULL and not fixed_version_id is NULL and ?<>fixed_version_id)
                                          )", self.root_id, self.lft, self.rgt,
                                              self.fixed_version_id, self.fixed_version_id,
                                              self.fixed_version_id, self.fixed_version_id]).each{|task|
            case Backlogs.platform
              when :redmine
                j = Journal.new
                j.journalized = task
                j.created_on = self.updated_on
                j.details << JournalDetail.new(:property => 'attr', :prop_key => 'fixed_version_id', :old_value => task.fixed_version_id, :value => fixed_version_id)
              when :chiliproject
                j = IssueJournal.new
                j.created_at = self.updated_on
                j.details['fixed_version_id'] = [task.fixed_version_id, self.fixed_version_id]
                j.activity_type = 'issues'
                j.journaled = task
                j.version = task.last_journal.version + 1
            end
            j.user = User.current
            j.save!

            tasks_updated << task
          }

          if tasks_updated.size > 0
            tasklist = '(' + tasks_updated.collect{|task| connection.quote(task.id)}.join(',') + ')'
            connection.execute("update issues set
                                updated_on = #{connection.quote(self.updated_on)}, fixed_version_id = #{connection.quote(self.fixed_version_id)}
                                where id in #{tasklist}")
          end

          connection.execute("update issues
                              set tracker_id = #{RbTask.tracker}
                              where root_id = #{self.root_id} and lft > #{self.lft} and rgt < #{self.rgt}")
        end

        if self.story || self.is_task?
          connection.execute("update issues set tracker_id = #{RbTask.tracker} where root_id = #{self.root_id} and lft >= #{self.lft} and rgt <= #{self.rgt}")
        end
      end

      def value_at(property, time)
        return history(property, [time.to_date])[0]
      end

      def history(property, days)
        property = property.to_s unless property.is_a?(String)
        raise "Unsupported property #{property.inspect}" unless RbJournal::JOURNALED_PROPERTIES.include?(property)

        days = days.to_a
        created_day = created_on.to_date
        active_days = days.select{|d| d >= created_day}

        # if not active, don't do anything
        return [nil] * (days.size + 1) if active_days.size == 0

        # anything before the creation date is nil
        prefix = [nil] * (days.size - active_days.size)

        # add one extra day as start-of-first-day
        active_days.unshift(active_days[0] - 1)

        journal = RbJournal.find(:all, :conditions => ['issue_id = ? and property = ?', self.id, property], :order => :timestamp).to_a
        if journal.size == 0
          RbJournal.rebuild(self)
          journal = RbJournal.find(:all, :conditions => ['issue_id = ? and property = ?', self.id, property], :order => :timestamp).to_a
          raise "Journal cannot have 0 entries" if journal.size == 0
        end

        values = [journal[0].value] * active_days.size

        journal.each{|change|
          stamp = change.timestamp.to_date
          day = active_days.index{|d| d >= stamp}
          break if day.nil?
          values.fill(change.value, day)
        }

        # ignore the start-of-day value for issues created mid-sprint
        values[0] = nil if created_day > days[0]

        return prefix + values
      end

    end
  end
end

Issue.send(:include, Backlogs::IssuePatch) unless Issue.included_modules.include? Backlogs::IssuePatch
