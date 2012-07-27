require_dependency 'projects_helper'

module Backlogs
  module ProjectsHelperPatch

    def self.included(base)
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)
      base.class_eval do
        unloadable
        alias_method_chain :project_settings_tabs, :hook
      end
    end

    module ClassMethods
    end

    module InstanceMethods
      def project_settings_tabs_with_hook
        tabs = project_settings_tabs_without_hook
        call_hook(:helper_projects_settings_tabs, { :tabs => tabs })
        return tabs
      end

      # Streamline the difference between <%=  %> and <%  %>
      def rb_form_for(*args, &proc)
        form_string = form_for(*args, &proc)
        if Rails::VERSION::MAJOR < 3
          form_string
        else
          concat(form_string)
        end
      end

    end
  end
end

ProjectsHelper.send(:include, Backlogs::ProjectsHelperPatch) unless ProjectsHelper.included_modules.include? Backlogs::ProjectsHelperPatch

