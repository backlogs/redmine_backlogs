require_dependency 'journal'

module Backlogs
  module JournalPatch
    def self.included(base) # :nodoc:
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)

      base.class_eval do
        unloadable

        after_save  :backlogs_after_save

        # added because acts_as_journal acts wonky -- some properties only show up after the 2nd save
        attr_accessor :rb_journal_properties_saved
      end
    end

    module ClassMethods
    end

    module InstanceMethods
      def backlogs_after_save
        RbJournal.journal(self)
      end
    end
  end
end

Journal.send(:include, Backlogs::JournalPatch) unless Journal.included_modules.include? Backlogs::JournalPatch
