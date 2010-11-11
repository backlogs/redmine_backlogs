include RbCommonHelper

# Responsible for exposing release CRUD.
class RbReleasesController < RbApplicationController
  unloadable

  def index
    @releases = Release.find(:all, :conditions => { :project_id => @project })
  end
  
end
