class RbAllProjectsController < ApplicationController
  unloadable

  before_filter :authorize_global

  def statistics
    @projects = RbCommonHelper.find_backlogs_enabled_active_projects
    @projects.sort! {|a, b| a.scrum_statistics.score <=> b.scrum_statistics.score}
  end

end
