include RbCommonHelper

class RbHooksRenderController < RbApplicationController
  unloadable

  def view_issues_sidebar
    locals = {
      :sprints => RbSprint.open_sprints(@project),
      :project => @project,
      :sprint => @sprint,
      :webcal => (request.ssl? ? 'webcals' : 'webcal'),
      :key => User.current.api_key
    }

    respond_to do |format|
      format.html { render :template => 'backlogs/view_issues_sidebar', :layout => false, :locals => locals, :handlers => [:erb], :formats => [:html] }
    end
  end

end
