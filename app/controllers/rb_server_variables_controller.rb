class RbServerVariablesController < RbApplicationController
  unloadable

  def show
    @section = params['section']
    respond_to do |format|
      format.js { render :layout => false }
    end
  end
end
