require_dependency 'issue'

module Backlogs
  module IssuePatch
    def self.included(base) # :nodoc:
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)

      base.class_eval do
        unloadable

        belongs_to :release, :class_name => 'RbRelease', :foreign_key => 'release_id'

        acts_as_list_with_gaps :default => (Backlogs.setting[:new_story_position] == 'bottom' ? 'bottom' : 'top')

        has_one :backlogs_history, :class_name => RbIssueHistory, :dependent => :destroy
        has_many :rb_release_burnchart_day_cache, :dependent => :delete_all


        validates_inclusion_of :release_relationship, :in => RbStory::RELEASE_RELATIONSHIP

        safe_attributes 'release_id','release_relationship' #FIXME merge conflict. is this required?

        before_save :backlogs_before_save
        after_save  :backlogs_after_save

        include Backlogs::ActiveRecord::Attributes
      end
    end

    module ClassMethods
    end

    module InstanceMethods
      def history
        @history ||= RbIssueHistory.find_or_create_by_issue_id(self.id)
      end

      def release_burnchart_day_caches(release_id)
        RbReleaseBurnchartDayCache.where(:issue_id => self.id, :release_id => release_id)
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
        if Backlogs.configured?(project)
          if (self.is_task? || self.story)
            self.remaining_hours = self.estimated_hours if self.remaining_hours.blank?
            self.estimated_hours = self.remaining_hours if self.estimated_hours.blank?

            self.remaining_hours = 0 if self.status.backlog_is?(:success)

            self.fixed_version = self.story.fixed_version if self.story
            self.start_date = Date.today if self.start_date.blank? && self.status_id != IssueStatus.default.id

            self.tracker = Tracker.find(RbTask.tracker) unless self.tracker_id == RbTask.tracker
          elsif self.is_story? && Backlogs.setting[:set_start_and_duedates_from_sprint]
            if self.fixed_version
              self.start_date ||= (self.fixed_version.sprint_start_date || Date.today)
              self.due_date ||= self.fixed_version.effective_date
              self.due_date = self.start_date if self.due_date && self.due_date < self.start_date
            else
              self.start_date = nil
              self.due_date = nil
            end
          end
        end
        self.remaining_hours = self.leaves.sum("COALESCE(remaining_hours, 0)").to_f unless self.leaves.empty?

        self.move_to_top if self.position.blank? || (@copied_from.present? && @copied_from.position == self.position)

        # scrub position from the journal by copying the new value to the old
        @attributes_before_change['position'] = self.position if @attributes_before_change

        @backlogs_new_record = self.new_record?

        return true
      end

      def invalidate_release_burnchart_data
        RbReleaseBurnchartDayCache.delete_all(["issue_id = ? AND day >= ?",self.id,Date.today])
        #FIXME Missing cleanup of older cache entries which is no longer
        # valid for any releases. Delete cache entries not related to
        # current release?
      end

      def backlogs_after_save
        self.history.save!
        self.invalidate_release_burnchart_data

        [self.parent_id, self.parent_id_was].compact.uniq.each{|pid|
          p = Issue.find(pid)
          r = p.leaves.sum("COALESCE(remaining_hours, 0)").to_f
          if r != p.remaining_hours
            p.update_attribute(:remaining_hours, r)
            p.history.save
          end
        }

        return unless Backlogs.configured?(self.project)

        if self.is_story?
          # raw sql and manual journal here because not
          # doing so causes an update loop when Issue calls
          # update_parent :<
          tasklist = RbTask.find(:all, :conditions => ["root_id=? and lft>? and rgt<? and
                                          (
                                            (? is NULL and not fixed_version_id is NULL)
                                            or
                                            (not ? is NULL and fixed_version_id is NULL)
                                            or
                                            (not ? is NULL and not fixed_version_id is NULL and ?<>fixed_version_id)
                                            or
                                            (tracker_id <> ?)
                                          )", self.root_id, self.lft, self.rgt,
                                              self.fixed_version_id, self.fixed_version_id,
                                              self.fixed_version_id, self.fixed_version_id,
                                              RbTask.tracker]).to_a
          tasklist.each{|task| task.history.save! }
          if tasklist.size > 0
            task_ids = '(' + tasklist.collect{|task| connection.quote(task.id)}.join(',') + ')'
            connection.execute("update issues set
                                updated_on = #{connection.quote(self.updated_on)}, fixed_version_id = #{connection.quote(self.fixed_version_id)}, tracker_id = #{RbTask.tracker}
                                where id in #{task_ids}")
          end
        end
      end

      def assignable_releases
        project.shared_releases
      end

      def release_id=(rid)
        self.release = nil
        write_attribute(:release_id, rid)
      end
#      def self.by_version(project)
#        count_and_group_by(:project => project,
#                           :field => 'release_id',
#                           :joins => RbRelease.table_name)
#      end


    end
  end
end

Issue.send(:include, Backlogs::IssuePatch) unless Issue.included_modules.include? Backlogs::IssuePatch
