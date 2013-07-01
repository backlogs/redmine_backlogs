require_dependency 'redmine/helpers/time_report'

module Backlogs
  module TimeReportPatch
    def self.included(base)
      base.send(:include, InstanceMethods)

      base.class_eval do
        alias_method_chain :load_available_criteria, :releases
      end
    end

    module InstanceMethods
      def load_available_criteria_with_releases
        load_available_criteria_without_releases
        @available_criteria["release"] = 
          { :sql => "#{Issue.table_name}.release_id",
            :klass => RbRelease,
            :label => :field_release
          }
        @available_criteria
      end
    end

  end
end

Redmine::Helpers::TimeReport.send(:include,Backlogs::TimeReportPatch) unless Redmine::Helpers::TimeReport.included_modules.include? Backlogs::TimeReportPatch
