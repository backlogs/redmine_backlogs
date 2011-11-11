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
      format.html { render :template => 'rb_burndown_charts/show.html.erb', :layout => false }
    end
  end

  def print
    @settings = Setting.plugin_redmine_backlogs
    respond_to do |format|
      format.html { render :layout => false }
    end
  end

end
