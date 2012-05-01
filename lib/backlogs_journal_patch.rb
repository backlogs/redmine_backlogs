require_dependency 'journal'

module Backlogs
  module JournalPatch
    def self.included(base) # :nodoc:
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)

      base.class_eval do
        unloadable

        after_create  :backlogs_after_create
      end
    end

    module ClassMethods
    end

    module InstanceMethods
      def backlogs_after_create
        RbJournal.journal(self)
      end
    end
  end
end

Journal.send(:include, Backlogs::JournalPatch) unless Journal.included_modules.include? Backlogs::JournalPatch
