class RbServerVariablesController < RbApplicationController
  unloadable

  def index
    @context = params[:context]
    respond_to do |format|
      format.js { render :file => 'rb_server_variables/show.js.erb', :layout => false }
    end
  end

  alias :project :index
  alias :sprint :index
end
