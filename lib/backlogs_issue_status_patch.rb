require_dependency 'user'

module Backlogs
  module IssueStatusPatch
    def self.included(base) # :nodoc:
        base.extend(ClassMethods)
        base.send(:include, InstanceMethods)
    end
  
    module ClassMethods
    end
  
    module InstanceMethods
      def backlog
        return :success if is_closed? && (default_done_ratio.nil? || default_done_ratio == 100)
        return :failure if is_closed?
        return :new if is_default? || default_done_ratio == 0
        return :in_progress
      end
    end
  end
end

IssueStatus.send(:include, Backlogs::IssueStatusPatch) unless IssueStatus.included_modules.include? Backlogs::IssueStatusPatch
