class RbAllProjectsController < ApplicationController
  unloadable

  before_filter :authorize_global

  def statistics
    @projects = EnabledModule.find(:all,
                                   :conditions => ["enabled_modules.name = 'backlogs' AND status = ?", Project::STATUS_ACTIVE],
                                   :include => :project,
                                   :joins => :project).collect { |mod| mod.project }
    @projects.sort! { |a, b| a.scrum_statistics.score <=> b.scrum_statistics.score }
  end

  def server_variables
    respond_to do |format|
      format.js { render :file => 'rb_server_variables/show.js.erb', :layout => false }
    end
  end
end
