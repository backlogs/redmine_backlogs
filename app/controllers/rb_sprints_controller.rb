include RbCommonHelper

# Responsible for exposing sprint CRUD. It SHOULD NOT be used
# for displaying the taskboard since the taskboard is a management
# interface used for managing objects within a sprint. For
# info about the taskboard, see RbTaskboardsController
class RbSprintsController < RbApplicationController
  unloadable
  
  def create
    attribs = params.select{|k,v| k != 'id' and RbSprint.column_names.include? k }
    attribs = Hash[*attribs.flatten]
    @sprint = RbSprint.new(attribs)

    begin
      @sprint.save!
    rescue => e
      render :text => e.message.blank? ? e.to_s : e.message, :status => 400
      return
    end

    result = @sprint.errors.length
    status = (result == 0 ? 200 : 400)

    respond_to do |format|
      format.html { render :partial => "sprint", :status => status }
    end
  end

  def update
    attribs = params.select{|k,v| k != 'id' and RbSprint.column_names.include? k }
    attribs = Hash[*attribs.flatten]
    begin
      result  = @sprint.update_attributes attribs
    rescue => e
      render :text => e.message.blank? ? e.to_s : e.message, :status => 400
      return
    end

    respond_to do |format|
      format.html { render :partial => "sprint", :status => (result ? 200 : 400) }
    end
  end
  
end
