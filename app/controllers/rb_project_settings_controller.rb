include RbCommonHelper
include ProjectsHelper

class RbProjectSettingsController < RbApplicationController
  unloadable

  def project_settings
    enabled = false
    enabled_scrum_stats = false
    if request.post? and params[:settings]
      enabled = true if params[:settings]["show_stories_from_subprojects"]=="enabled"
      enabled_scrum_stats = true if params[:settings]["show_in_scrum_stats"]=="enabled"
    end
    settings = @project.rb_project_settings
    settings.show_stories_from_subprojects = enabled
    settings.show_in_scrum_stats = enabled_scrum_stats
    if settings.save
      flash[:notice] = t(:rb_project_settings_updated)
    else
      flash[:error] = t(:rb_project_settings_update_error)
    end
    redirect_to :controller => 'projects', :action => 'settings', :id => @project,
                :tab => 'backlogs'
  end

end
