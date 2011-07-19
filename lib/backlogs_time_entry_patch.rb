#coding:utf-8
require_dependency 'time_entry'

module Backlogs
  module TimeEntryPatch
  
  def self.included(base)
    base.send(:include, InstanceMethods)
    base.class_eval do
      #alias_method_chain :after_create, :update4create_remaining_hours
      #alias_method_chain :after_update, :update4update_remaining_hours
      alias_method_chain :before_save, :block_invalid_spent_hour
    end
  end
  
  module InstanceMethods
    def after_create_with_update4create_remaining_hours
      after_create_without_update4create_remaining_hours
      return if issue.status.is_closed?

      note = "#{l(:label_insert_spent_hour)} #{hours}h #{comments}"
      update_remaining_hours(note, hours)
    end

    def after_update_with_update4update_remaining_hours
      after_update_without_update4update_remaining_hours
      return if issue.status.is_closed?

      note = "#{l(:label_update_spent_hour)} #{hours_was} -> #{hours}h #{comments}"
      update_remaining_hours(note, hours - hours_was)
    end

    def update_remaining_hours(note, hours)
      issue.init_journal(User.current, note) unless issue.current_journal
      issue.remaining_hours ||= 0.0
      issue.remaining_hours -= hours
      issue.save
    end

    def before_save_with_block_invalid_spent_hour
      before_save_without_block_invalid_spent_hour

      return true unless project.module_enabled?('backlogs')
      if issue.tracker_id == Setting.plugin_redmine_backlogs[:task_tracker].to_i
        return true unless issue.status.is_default?
        errors.add_to_base("タスクのステータスが#{issue.status}のままになってるので入力できません＞＜")
        return false
      end
      return true unless Setting.plugin_redmine_backlogs[:story_trackers].map{|t|t.to_i}.include?(issue.tracker_id)
      
      errors.add_to_base("ストーリには時間を入力できません。タスクにつけてください。")
      false
    end
  end
  end
end

TimeEntry.send(:include, Backlogs::TimeEntryPatch) unless TimeEntry.included_modules.include? Backlogs::TimeEntryPatch

