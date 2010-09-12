class RbCustomStylesController < RbApplicationController
  unloadable

  def show
    respond_to do |format|
      format.css { render :layout => false }
    end
  end
end
