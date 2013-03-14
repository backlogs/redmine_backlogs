# Base class of all controllers in Redmine Backlogs
class RbApplicationController < ApplicationController
  unloadable

  before_filter :load_project, :authorize, :check_if_plugin_is_configured

  #provide list of javascript_include_tags which must be rendered before common.js
  def rb_jquery_plugins
    @rb_jquery_plugins
  end
  def rb_jquery_plugins=(html)
    @rb_jquery_plugins = html
  end

  private

  # Loads the project to be used by the authorize filter to
  # determine if User.current has permission to invoke the method in question.
  def load_project
    @project = if params[:sprint_id]
                 load_sprint
                 @sprint.project
               elsif params[:release_id] && !params[:release_id].empty?
                 load_release
                 @release.project
               elsif params[:project_id]
                 Project.find(params[:project_id])
               else
                 raise "Cannot determine project (#{params.inspect})"
               end
  end

  def check_if_plugin_is_configured
    @settings = Backlogs.settings
    if @settings[:story_trackers].blank? || @settings[:task_tracker].blank?
      respond_to do |format|
        format.html { render :file => "backlogs/not_configured" }
      end
    end
  end

  def load_sprint
    @sprint = RbSprint.find(params[:sprint_id])
  end

  def load_release
    @release = RbRelease.find(params[:release_id])
  end
end
