include RbCommonHelper

class RbBurndownChartsController < RbApplicationController
  unloadable

  def show
    respond_to do |format|
      format.html { render :layout => false }
    end
  end

  def print
    respond_to do |format|
      format.html { render :layout => false }
    end
  end

end
