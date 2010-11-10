include RbCommonHelper

# Responsible for exposing release CRUD.
class RbReleasesController < RbApplicationController
  unloadable

  def index
    @releases = Release.all
    @the_test = "Let's see what happens"
  end

  def show
    @release = Release.find(params[:id])
  end
  
end
