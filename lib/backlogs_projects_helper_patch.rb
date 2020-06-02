require_dependency 'projects_helper'

module Backlogs
  module ProjectsHelperPatch

    def project_settinags_tabs
      tabs = super
      tabs << {:name => 'backlogs',
        :action => :manage_project_backlogs,
        :partial => 'backlogs/project_settings',
        :label => :label_backlogs
      } if @project.module_enabled?('backlogs') and 
           User.current.allowed_to?(:configure_backlogs, nil, :global=>true)
      return tabs
    end

  end
end

module ProjectsHelper
  unloadable
  prepend Backlogs::ProjectsHelperPatch
end
