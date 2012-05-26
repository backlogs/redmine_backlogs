require_dependency 'version'

module Backlogs
  module VersionPatch
    def self.included(base) # :nodoc:
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)

      base.class_eval do
        unloadable

        include Backlogs::ActiveRecord::Attributes
      end
    end

    module ClassMethods
    end

    module InstanceMethods
      def burndown
        return RbSprint.find_by_id(self.id).burndown
      end

    end
  end
end

Version.send(:include, Backlogs::VersionPatch) unless Version.included_modules.include? Backlogs::VersionPatch
