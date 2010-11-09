include RbCommonHelper

# Responsible for exposing release CRUD.
class RbReleaseController < RbApplicationController
  unloadable
  
  def update
    attribs = params.select{|k,v| k != 'id' and Release.column_names.include? k }
    attribs = Hash[*attribs.flatten]
    result  = @release.update_attributes attribs
    status  = (result ? 200 : 400)
    
    respond_to do |format|
      format.html { render :partial => "release", :status => status }
    end
  end
  
end
