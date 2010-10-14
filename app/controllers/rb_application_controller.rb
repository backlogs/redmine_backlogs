# Base class of all controllers in Redmine Backlogs
class RbApplicationController < ApplicationController
  unloadable

  before_filter :load_context, :authorize, :check_if_plugin_is_configured

  private

  # Loads the project/sprint to be used by the authorize filter to
  # determine if User.current has permission to invoke the method in question.
  def load_context

    # load a shared sprint in the context of a given project
    if params[:project_id] && params[:sprint_id].present?
      @project = Project.find(params[:project_id])
      @sprint = @project.sprint(params[:sprint_id])

    # load a sprint in the context of the project that owns it
    elsif params[:sprint_id].present?
      #@sprint = Sprint.find(params[:sprint_id])
      #@project = @sprint.project
      raise "It's best to always explicitly load the project now we have shared sprints"

    # load only a project
    elsif params[:project_id]
      @project = Project.find(params[:project_id])

    else
      render :text => "Cannot determine project (#{params.inspect})", :status => 400

    end
  end
  
  def check_if_plugin_is_configured
    settings = Setting.plugin_redmine_backlogs
    if settings[:story_trackers].blank? || settings[:task_tracker].blank?
      respond_to do |format|
        format.html { render :file => "shared/not_configured" }
      end
    end
  end

end
