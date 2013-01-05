class RbAllProjectsController < ApplicationController
  unloadable

  before_filter :authorize_global

  def statistics
    backlogs_projects = RbCommonHelper.find_backlogs_enabled_active_projects
    @projects = []
    backlogs_projects.each{|p|
      @projects << p unless p.visible?.nil? || p.rb_project_settings.show_in_scrum_stats == false
    }
    @projects.sort! {|a, b| a.scrum_statistics.score <=> b.scrum_statistics.score}
  end

end
