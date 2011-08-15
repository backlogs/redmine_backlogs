include RbCommonHelper

class RbImpedimentsController < RbApplicationController
  unloadable

  def create
    @impediment = RbTask.create_with_relationships(params, User.current.id, @project.id, true)
    result = @impediment.errors.length
    status = (result == 0 ? 200 : 400)
    @include_meta = true
    
    respond_to do |format|
      format.html { render :partial => "impediment", :object => @impediment, :status => status }
    end
  end

  def update
    @impediment = RbTask.find_by_id(params[:id])
    result = @impediment.update_with_relationships(params)
    status = (result ? 200 : 400)
    @include_meta = true
    
    respond_to do |format|
      format.html { render :partial => "impediment", :object => @impediment, :status => status }
    end
  end

end
