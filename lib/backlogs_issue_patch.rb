require_dependency 'issue'

module Backlogs
  module IssuePatch
    def self.included(base) # :nodoc:
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)

      base.class_eval do
        unloadable

        alias_method_chain :move_to_project_without_transaction, :autolink
        after_save  :backlogs_after_save

        before_save :backlogs_scrub_position_journal
      end
    end

    module ClassMethods
    end

    module InstanceMethods
      def move_to_project_without_transaction_with_autolink(new_project, new_tracker = nil, options = {})

        newissue = move_to_project_without_transaction_without_autolink(new_project, new_tracker, options)
        return newissue if newissue.blank? || !self.project.module_enabled?('backlogs')

        if self.project_id == newissue.project_id and self.is_story? and newissue.is_story? and self.id != newissue.id
          relation = IssueRelation.new :relation_type => IssueRelation::TYPE_DUPLICATES
          relation.issue_from = self
          relation.issue_to = newissue
          relation.save
        end

        return newissue
      end

      def journalized_update_attributes!(attribs)
        self.init_journal(User.current)
        return self.update_attributes!(attribs)
      end

      def journalized_update_attributes(attribs)
        self.init_journal(User.current)
        return self.update_attributes(attribs)
      end

      def journalized_update_attribute(attrib, v)
        self.init_journal(User.current)
        self.update_attribute(attrib, v)
      end

      def is_story?
        return RbStory.trackers.include?(self.tracker_id)
      end

      def is_task?
        return (self.parent_id && self.tracker_id == RbTask.tracker)
      end

      def story
        # the self.id test verifies we're not looking at a new,
        # unsaved issue object
        return nil unless self.id && self.is_task?

        return Issue.find(:first, :order => 'lft DESC',
          :conditions => [ "root_id = ? and lft < ? and tracker_id in (?)", self.root_id, self.lft, RbStory.trackers ]).becomes(RbStory)
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

        dpp = self.project.scrum_statistics.info[:average_days_per_point]
        return nil if ! dpp

        return Integer(self.story_points * dpp)
      end

      def backlogs_scrub_position_journal
        @issue_before_change.position = self.position if @issue_before_change
      end

      def backlogs_after_save
        ## automatically sets the tracker to the task tracker for
        ## any descendant of story, and follow the version_id
        ## Normally one of the _before_save hooks ought to take
        ## care of this, but appearantly neither root_id nor
        ## parent_id are set at that point

        return unless self.project.module_enabled? 'backlogs'

        if self.is_story?
          # raw sql here because it's efficient and not
          # doing so causes an update loop when Issue calls
          # update_parent

          if not RbTask.tracker.nil?
            tasks = self.descendants.collect{|t| connection.quote(t.id)}.join(",")
            if tasks != ""
              connection.execute("update issues set tracker_id=#{connection.quote(RbTask.tracker)}, fixed_version_id=#{connection.quote(self.fixed_version_id)} where id in (#{tasks})")
            end
          end

        elsif self.is_task?
          story = self.story
          if not story.blank?
            connection.execute "update issues set tracker_id = #{connection.quote(RbTask.tracker)}, fixed_version_id = #{connection.quote(story.fixed_version_id)} where id = #{connection.quote(self.id)}"
          end

          connection.execute("update issues set estimated_hours = 0 where id = #{connection.quote(self.id)}") if self.status.backlog == :success
        end
      end

      def historic(date, property)
        case date
          when :last
            return self.send(property.intern)
          when nil
            return nil
        end

        Rails.cache.fetch("RbIssue(#{id}).historic(#{date}, #{property})", :force => date.is_a?(Symbol) || date.to_date == Date.today) {
          if date == :first
            conditions = ["property = 'attr' and prop_key = '#{property}' and journalized_type = 'Issue' and journalized_id = ?", id]
          else
            conditions = ["property = 'attr' and prop_key = '#{property}' and journalized_type = 'Issue' and journalized_id = ? and journals.created_on > ?", id, date]
          end

          j = JournalDetail.find(:first, :order => "journals.created_on asc", :joins => :journal, :conditions => conditions)

          if j.nil?
            v = self.send(property.intern)
          else
            v = j.old_value || j.value

            if v
              @@backlogs_column_type ||= {}
              @@backlogs_column_type[property] ||= Issue.connection.columns(Issue.table_name).select{|c| c.name == property}.collect{|c| c.type}[0]

              case @@backlogs_column_type[property]
                when :integer
                  v = Integer(v)
                when :float
                  v = Float(v)
                when :string
                  v = v.to_s
                else
                  raise "Unexpected field type '#{@@backlogs_column_type[property].inspect}' for Issue##{property}"
              end
            end
          end

          v
        }
      end

      def initial_estimate
        return nil unless (RbStory.trackers + [RbTask.tracker]).include?(tracker_id)

        if self.leaf?
          return self.historic(:first, 'estimated_hours')
        else
          e = self.leaves.collect{|t| t.initial_estimate}.compact
          return nil if e.size == 0
          return e.sum
        end
      end
    end
  end
end

Issue.send(:include, Backlogs::IssuePatch) unless Issue.included_modules.include? Backlogs::IssuePatch
