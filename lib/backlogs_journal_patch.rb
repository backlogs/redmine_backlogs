require_dependency 'journal'

module Backlogs
  module JournalPatch
    def self.included(base) # :nodoc:
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)

      base.class_eval do
        unloadable

        after_save  :backlogs_after_save
      end
    end

    module ClassMethods
    end

    module InstanceMethods
      def backlogs_after_save
        RbIssueHistory.process(self)
      end
    end
  end
end

Journal.send(:include, Backlogs::JournalPatch) unless Journal.included_modules.include? Backlogs::JournalPatch
