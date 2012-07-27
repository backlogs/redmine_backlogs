include RbCommonHelper
include ProjectsHelper

class RbSettingsController < RbApplicationController
  unloadable

  def projectsettings
    enabled = false
    if request.post? and params[:settings] and params[:settings]["show_stories_from_subprojects"]=="enabled"
      enabled = true
    end
    Backlogs.setting["dont_show_stories_from_subprojects_#{@project.id}"] = !enabled
    redirect_to :controller => 'projects', :action => 'settings', :id => @project, :tab => 'backlogs'
  end

end
