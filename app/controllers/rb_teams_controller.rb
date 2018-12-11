include RbCommonHelper
include RbFormHelper
include ProjectsHelper

class RbTeamsController < RbApplicationController

  def create
    @team = RbTeam.new(:project => @project)
    if request.post?
      if @team.areAttributesAssignedCorrectly?(params[:post])
        flash[:notice] = @team.success
        redirect_to :controller => 'rb_master_backlogs', :action => 'show',
                    :project_id => @project, :team_parameters => @team.getParams,
                    :process_many_sprint => true
      else
        flash[:error] = @team.fail
        redirect_to :controller => 'rb_master_backlogs', :action => 'show', :project_id => @project
      end
    end
  end

end
