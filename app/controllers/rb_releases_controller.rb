include RbCommonHelper

# Responsible for exposing release CRUD.
class RbReleasesController < RbApplicationController
  unloadable

  def index
    @project_id = @project.id
    @releases = Release.find(:all, :conditions => { :project_id => @project_id })
  end
  
end
