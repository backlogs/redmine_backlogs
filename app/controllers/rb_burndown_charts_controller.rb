include RbCommonHelper

class RbBurndownChartsController < RbApplicationController
  unloadable

  def show
    respond_to do |format|
      format.html
    end
  end

  def embedded
    respond_to do |format|
      format.html { render :template => 'rb_burndown_charts/show', :layout => false, :handlers => [:erb], :formats => [:html] }
    end
  end

  def print
    @width = Backlogs.setting[:burndown_print_width].to_s
    @height = Backlogs.setting[:burndown_print_height].to_s
    if @width.blank? || @height.blank?
      @width = '1300'
      @height = '600'
    end
    respond_to do |format|
      format.html { render :layout => false }
    end
  end

end
