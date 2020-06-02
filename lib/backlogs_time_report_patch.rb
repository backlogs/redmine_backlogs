require_dependency 'redmine/helpers/time_report'

module Backlogs
  module TimeReportPatch

    def load_available_criteria
      super
      @available_criteria["release"] =
        { :sql => "COALESCE((select release_id from #{Issue.table_name} where id=parent_issue.parent_id), #{Issue.table_name}.release_id)",
          :joins => "left outer join #{Issue.table_name} parent_issue on parent_issue.id = #{TimeEntry.table_name}.issue_id",
          :klass => RbRelease,
          :label => :field_release
        }
      @available_criteria
    end

  end
end

Redmine::Helpers::TimeReport.prepend(Backlogs::TimeReportPatch)
