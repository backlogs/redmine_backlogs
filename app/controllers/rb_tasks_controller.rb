include RbCommonHelper

class RbTasksController < RbApplicationController
  unloadable

  def create
    @settings = Setting.plugin_redmine_backlogs
    @task = nil
    begin
      @task  = RbTask.create_with_relationships(params, User.current.id, @project.id)
    rescue => e
      render :text => e.message.blank? ? e.to_s : e.message, :status => 400
      return
    end

    result = @task.errors.length
    status = (result == 0 ? 200 : 400)
    @include_meta = true
    
    respond_to do |format|
      format.html { render :partial => "task", :object => @task, :status => status }
    end
  end

  def update
    @task = RbTask.find_by_id(params[:id])
    @settings = Setting.plugin_redmine_backlogs
    result = @task.update_with_relationships(params)
    status = (result ? 200 : 400)
    @include_meta = true
    
    respond_to do |format|
      format.html { render :partial => "task", :object => @task, :status => status }
    end
    story = @task.story
    if story !=nil
      chk = true
      RAILS_DEFAULT_LOGGER.info "story: #{story}"
      story.tasks.each{|task| 
        RAILS_DEFAULT_LOGGER.info "task: #{task}(#{task.status.is_closed?})"
        chk == false if task.status.is_closed?
      }
      if chk == true
        tracker = Tracker.find_by_id(RbTask.tracker)
        statuses = tracker.issue_statuses
        RAILS_DEFAULT_LOGGER.info "close status: #{statuses[5]}"
#        story.status_id = 4
        story.update_and_position!({'status_id' => "5"})
        story.reload
      end
    end
  end

end
