include RbCommonHelper
include ProjectsHelper

class RbSettingsController < RbApplicationController
  unloadable

  def projectsettings
    enabled = false
    if params[:settings] and params[:settings]["show_stories_from_subprojects"]=="enabled"
      enabled = true
    end
    Backlogs.setting["dont_show_stories_from_subprojects_#{@project.id}"] = !enabled
    render(:update) {|page| page.replace_html "tab-content-backlogs", :partial => 'backlogs/projectsettings'}
  end

end
