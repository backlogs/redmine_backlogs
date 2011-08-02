include RbCommonHelper

class RbTasksController < RbApplicationController
  unloadable

  def create
    initial_estimate = params.delete('initial_estimate')
    @task  = RbTask.create_with_relationships(params, User.current.id, @project.id)
    result = @task.errors.length
    status = (result == 0 ? 200 : 400)
    @include_meta = true

    @task.set_initial_estimate(Float(initial_estimate)) if status == '200' && initial_estimate
    
    respond_to do |format|
      format.html { render :partial => "task", :object => @task, :status => status }
    end
  end

  def update
    initial_estimate = params.delete('initial_estimate')
    @task = RbTask.find_by_id(params[:id])
    result = @task.update_with_relationships(params)
    status = (result ? 200 : 400)
    @include_meta = true
    @task.set_initial_estimate(Float(initial_estimate)) if status == '200' && initial_estimate
    
    respond_to do |format|
      format.html { render :partial => "task", :object => @task, :status => status }
    end
  end

end
