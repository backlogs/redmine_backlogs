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
        return RbStory.trackers.include?(tracker_id)
      end

      def is_task?
        return (tracker_id == RbTask.tracker)
      end

      def story
        # the self.id test verifies we're not looking at a new, unsaved issue object
        return nil unless self.id

        unless @rb_story
          @rb_story = Issue.find(:first, :order => 'lft DESC', :conditions => [ "root_id = ? and lft < ? and tracker_id in (?)", root_id, lft, RbStory.trackers ])
          @rb_story = @rb_story.becomes(RbStory) if @rb_story
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

      def relative_priority
        if ((relative_gain == nil || relative_gain.blank?) && (relative_penalty == nil || relative_penalty.blank?) && (relative_risk == nil || relative_risk.blank?) && (story_points == nil || story_points.blank?))
          @relative_priority = 0
        else
          @relative_priority = ((relative_gain.to_f + relative_penalty.to_f) / (story_points.to_f + relative_risk.to_f)).to_f.round(2)
        end
      end
    
      def velocity_based_estimate
        return nil if !self.is_story? || ! self.story_points || self.story_points <= 0

        dpp = self.project.scrum_statistics.info[:average_days_per_point]
        return nil if ! dpp

        return Integer(self.story_points * dpp)
      end

      def backlogs_before_save
        if @issue_before_change && self.project.module_enabled?('backlogs')
          @issue_before_change.position = self.position # don't log position updates

          if self.is_task?
            estimated_hours = 0 if status.backlog == :success
            position = @issue_before_change.position = nil
            fixed_version_id = story.fixed_version_id if story
          end
        end
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
          connection.execute("update issues set fixed_version_id = #{connection.quote(fixed_version_id)} where id in (#{descendants.collect{|t| "#{t.id}"}.join(',')})") unless leaf?

          # safe to do by sql since we don't want any of this logged
          unless self.position
            max = 0
            connection.execute('select max(position) from issues where not position is null').each {|i| max = i[0] }
            connection.execute("update issues set position = #{connection.quote(max)} + 1 where id = #{id}")
          end
        end
      end

      def initial_value_for(property)
        jd = JournalDetail.find(:first, :order => "journals.created_on asc" , :joins => :journal,
                                        :conditions => ["property = 'attr' and prop_key = '#{property}'
                                                         and journalized_type = 'Issue' and journalized_id = ?", id])
        return jd ? jd.old_value : self.send(property)
      end

      def history(property, days)
        created_day = created_on.to_date
        active_days = days.select{|d| d >= created_day}

        values = [nil] * active_days.size

        first = nil
        if active_days.size != 0
          first = initial_value_for(property)
          values.fill(first)
          first = nil if active_days.size != days.size

          JournalDetail.find(:all, :order => "journals.created_on asc" , :joins => :journal,
                                   :conditions => ["created_on between ? and ?
                                                    and property = 'attr' and prop_key = '#{property}'
                                                    and journalized_type = 'Issue' and journalized_id = ?",
                                                    active_days[0].to_time, (active_days[-1] + 1).to_time, id]).each {|detail|
            jdate = detail.journal.created_on.to_date
            i = active_days.index{|d| d >= jdate}
            break unless i

            values.fill(detail.value, i)
          }
          values[-1] = self.send(property)
        end

        values = ([nil] * (days.size - active_days.size)) + [first] + values

        @@backlogs_column_type ||= {}
        @@backlogs_column_type[property] ||= Issue.connection.columns(Issue.table_name).select{|c| c.name == "#{property}"}.collect{|c| c.type}[0]

        return values.collect{|v|
          if v.nil?
            v
          else
            case @@backlogs_column_type[property]
              when :integer
                Integer(v)
              when :float
                Float(v)
              when :string
                v.to_s
              else
                raise "Unexpected field type '#{@@backlogs_column_type[property].inspect}' for Issue##{property}"
            end
          end
        }
      end

      def initial_estimate
        return nil unless (RbStory.trackers + [RbTask.tracker]).include?(tracker_id)

        if leaf?
          return initial_value_for(:estimated_hours)
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
