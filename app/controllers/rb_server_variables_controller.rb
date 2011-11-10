class RbServerVariablesController < RbApplicationController
  unloadable

  def show
    @caller = params['caller']
    respond_to do |format|
      format.js { render :layout => false }
    end
  end
end
