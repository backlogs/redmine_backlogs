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
      def backlog(tracker=nil)
        unless tracker
          Rails.logger.warn("IssueStatus.backlog called without parameter")
          begin 5 / 0; rescue => e; Rails.logger.warn e; Rails.logger.warn e.backtrace.join("\n"); end
        end
        if Redmine::VERSION::MAJOR >= 3 && tracker
          is_default = tracker.default_status_id == id
        else
          is_default = is_default?
        end
        return :success if is_closed? && (default_done_ratio.nil? || default_done_ratio == 100)
        return :failure if is_closed?
        return :new if is_default || default_done_ratio == 0
        return :in_progress
      end

      def backlog_is?(states, tracker=nil)
        states = [states] unless states.is_a?(Array)
        raise "Not a valid state set #{states.inspect}" unless (states - [:success, :failure, :new, :in_progress]) == []
        return states.include?(backlog(tracker))
      end
    end
  end
end

IssueStatus.send(:include, Backlogs::IssueStatusPatch) unless IssueStatus.included_modules.include? Backlogs::IssueStatusPatch
