require_dependency 'version'

module Backlogs
  module VersionPatch
    def self.included(base) # :nodoc:
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)

      base.class_eval do
        unloadable

        after_save  :backlogs_after_save
        before_destroy :backlogs_before_destroy
      end
    end
  
    module ClassMethods
    end
  
    module InstanceMethods
      def burndown
        return RbSprint.find_by_id(self.id).burndown
      end

      def backlogs_before_destroy
        if project.module_enabled?('backlogs')
          self.fixed_issues.each{|i|
            Rails.cache.delete("RbIssue(#{i.id}).burndown")
          }
        end
      end

      def backlogs_before_save
        if project.module_enabled?('backlogs') && !self.new_record?
          self.fixed_issues.each{|i|
            Rails.cache.delete("RbIssue(#{i.id}).burndown")
          }
        end
      end
  
    end
  end
end

Version.send(:include, Backlogs::VersionPatch) unless Version.included_modules.include? Backlogs::VersionPatch
