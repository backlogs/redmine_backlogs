include RbCommonHelper

class RbTasksController < RbApplicationController
  unloadable

  def create
    @settings = Backlogs.settings
    @task = nil
    begin
      @task  = RbTask.create_with_relationships(params, User.current.id, @project.id)
    rescue => e
      render :text => e.message.blank? ? e.to_s : e.message, :status => 400
      return
    end

    result = @task.errors.size
    status = (result == 0 ? 200 : 400)
    @include_meta = true

    respond_to do |format|
      format.html { render :partial => "task", :object => @task, :status => status }
    end
  end

  def update
    @task = RbTask.find_by_id(params[:id])
    @settings = Backlogs.settings
    $stderr.puts "task_controller update params #{params}"
    result = @task.update_with_relationships(params)
    status = (result ? 200 : 400)
    @include_meta = true

    #@task.story.story_follow_task_state if @task.story

    settings = Setting['plugin_redmine_issue_status']
    #puts "\n\n\n\n\n settings #{settings}"
    #puts "\n\n\n\n\ #{settings} #{@task.parent} #{(@task.status)} #{(@task.status_was)}"
    
    #puts "\n\n\nprojeto configurado? #{settings['projects_list'].include? @task.project.id.to_s}"

    begin
      $stderr.puts "\n\n\n\n\n erros: #{@task.errors.any?} \n result: #{result}"

      verify_children @task, settings if (!@task.errors.any? && result && @task.project && (settings['projects_list']) && (settings['projects_list'].include? @task.project.id.to_s)) 
      #$stderr.puts "Verify children redmine_issue_status sucessfully"
    rescue => e
      $stderr.puts "\n\n Error processing redmine_issue_status #{e.message} #{@task.inspect}"
      @task.errors.clear
    end

    respond_to do |format|
      format.html { render :partial => "task", :object => @task, :status => status }
    end
  end

  def verify_children(issue,settings)

      if issue.parent && issue.parent.children
      
          status = issue.status
          issue.parent.children.each do |c|         
            if (settings['at_least_statuses_list'].include? c.status.id.to_s)
              issue.parent.status = c.status
              issue.parent.save   
              return
            end
            status = c.status if c.status.position < status.position
          end 

          if (settings['minor_statuses_list'].include? status.id.to_s) && (issue.parent.status != status)
            puts "\n\n\n\n Minor status #{status}"
            issue.parent.status = status
            issue.parent.save

          end

      end

    end

end
