require_dependency 'projects_helper'

module Backlogs
  module ProjectsHelperPatch

    def self.included(base)
      base.send(:include, InstanceMethods)
      base.class_eval do
        unloadable
        alias_method_chain :project_settings_tabs, :backlogs
      end
    end

    module InstanceMethods

      def project_settings_tabs_with_backlogs
        tabs = project_settings_tabs_without_backlogs
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
end

ProjectsHelper.send(:include, Backlogs::ProjectsHelperPatch) unless ProjectsHelper.included_modules.include? Backlogs::ProjectsHelperPatch

