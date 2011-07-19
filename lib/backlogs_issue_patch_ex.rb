#coding:utf-8
require_dependency 'issue'

module Backlogs
  module IssuePatchEx
  
  def self.included(base)
    base.send(:include, InstanceMethods)
    base.class_eval do
      alias_method_chain :before_save, :require_tasks_done_when_story_done
      alias_method_chain :before_save, :require_estimated_hours_when_status_update
      alias_method_chain :before_save, :require_assignee_when_status_in_progress
      alias_method_chain :before_save, :note_required_on_close
    end
  end
  
  module InstanceMethods
    def before_save_with_require_tasks_done_when_story_done
      valid_save = before_save_without_require_tasks_done_when_story_done

      return valid_save unless project.module_enabled?('backlogs')
      return valid_save unless Setting.plugin_redmine_backlogs[:story_trackers].map{|t|t.to_i}.include?(tracker_id)
      return valid_save unless status_id_changed?
      return valid_save unless IssueStatus.find(status_id).is_closed?
      return valid_save if children.select {|task| !task.closed?}.empty?

      errors.add_to_base("タスクをすべて終了させてからストーリを終了させてね")
      false
    end
    
    def before_save_with_require_estimated_hours_when_status_update
      valid_save = before_save_without_require_estimated_hours_when_status_update

      return valid_save unless project.module_enabled?('backlogs')
      return valid_save unless tracker_id == Setting.plugin_redmine_backlogs[:task_tracker].to_i
      return valid_save if new_record?
      return valid_save unless status_id_changed?
      return valid_save if IssueStatus.find(status_id).is_closed?

      return valid_save if estimated_hours and estimated_hours > 0.0
      
      errors.add_to_base("旦那…。予定時間が入っていませんぜ？")
      false
    end

    def before_save_with_require_assignee_when_status_in_progress
      valid_save = before_save_without_require_assignee_when_status_in_progress

      return valid_save unless project.module_enabled?('backlogs')
      return valid_save unless tracker_id == Setting.plugin_redmine_backlogs[:task_tracker].to_i
      return valid_save if new_record?
      return valid_save unless status_id_changed?
      return valid_save if IssueStatus.find(status_id).is_closed?

      return valid_save if assigned_to
      
      errors.add_to_base("先生！担当者がいません！")
      false
    end

    # original is https://github.com/ajwalters/redmine_require_closing_note/tree
    def before_save_with_note_required_on_close
      valid_save = before_save_without_note_required_on_close
      if require_note?
        # New records do _NOT_ have a notes field
        if @current_journal.notes.blank?
          errors.add_to_base("後から思い出せるように経緯を書いてください。却下するなら却下した理由がありますよね。")
          valid_save = false
        end
      end
      valid_save #= valid_save ? before_save_without_note_required_on_close : false
    end
    
    private
    
    # A note is not required for a new issue.  Notes are only required when the issues status is changed from an open status to a closed.
    def require_note?
      !new_record? && status_id_changed? && !IssueStatus.find(status_id_was).is_closed? && IssueStatus.find(status_id).is_closed?
    end
  end
  end
end

Issue.send(:include, Backlogs::IssuePatchEx) unless Issue.included_modules.include? Backlogs::IssuePatchEx

