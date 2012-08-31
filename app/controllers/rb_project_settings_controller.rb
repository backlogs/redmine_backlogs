include RbCommonHelper
include ProjectsHelper

class RbProjectSettingsController < RbApplicationController
  unloadable

  def project_settings
    enabled = false
    if request.post? and params[:settings] and params[:settings]["show_stories_from_subprojects"]=="enabled"
      enabled = true
    end
    settings = @project.rb_project_settings
    settings.show_stories_from_subprojects = enabled
    if settings.save
      flash[:notice] = t(:rb_project_settings_updated)
    else
      flash[:error] = t(:rb_project_settings_update_error)
    end
    redirect_to :controller => 'projects', :action => 'settings', :id => @project,
                :tab => 'backlogs'
  end

end
