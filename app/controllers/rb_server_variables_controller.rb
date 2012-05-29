class RbServerVariablesController < RbApplicationController
  unloadable

  # for index there's no @project
  # (eliminates the need of RbAllProjectsController)
  skip_before_filter :load_project, :authorize, :only => [:index]

  def index
    @context = params[:context]
    respond_to do |format|
      format.html { render_404 }
      format.js { render :file => 'rb_server_variables/show.js.erb', :layout => false }
    end
  end

  alias :project :index
  alias :sprint :index
end
