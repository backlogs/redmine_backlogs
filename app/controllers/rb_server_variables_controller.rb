class RbServerVariablesController < RbApplicationController
  unloadable
  #FIXME this effectively allows csrf attacks on /rb/server_variables.js FIXME
  skip_before_action :verify_authenticity_token, if: :js_request?

  skip_before_action :verify_authenticity_token

  # for index there's no @project
  # (eliminates the need of RbAllProjectsController)
  skip_before_filter :load_project, :authorize, :only => [:index]

  def index
    @context = params[:context]

    respond_to do |format|
      Rails.logger.warn("Format problem #{format}")
      format.html { render_404 }
      format.js { render :template => 'rb_server_variables/show', :layout => false, :handlers => [:erb], :formats => [:js] }
      #format.js { render js: "alert('Hello Rails');" }
    end
  end

  alias :project :index
  alias :sprint :index

  def js_request?
    request.format.js?
  end
end
