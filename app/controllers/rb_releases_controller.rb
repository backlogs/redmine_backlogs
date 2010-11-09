include RbCommonHelper

# Responsible for exposing release CRUD.
class RbReleasesController < RbApplicationController
  unloadable

  # FIXME
  def show
    @releases = Release.find(:first)
  end
  
end
