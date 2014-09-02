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
        return :success if ([5,9].include?(id))
        return :failure if id == 6 
        return :new if id == 1
        return :in_progress
      end

      def backlog_is?(states)
        states = [states] unless states.is_a?(Array)
        raise "Not a valid state set #{states.inspect}" unless (states - [:success, :failure, :new, :in_progress]) == []
        return states.include?(backlog)
      end
    end
  end
end

IssueStatus.send(:include, Backlogs::IssueStatusPatch) unless IssueStatus.included_modules.include? Backlogs::IssueStatusPatch
