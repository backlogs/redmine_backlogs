include RbCommonHelper
include RbFormHelper
include ProjectsHelper

class RbReleasesMultiviewController < RbApplicationController
  unloadable

  def index
  end

  def show
    respond_to do |format|
      format.html { render }
    end
  end

  def new
    @release_multiview = RbReleaseMultiview.new(:project => @project)
    if request.post?
      # Convert id's into numbers and remove blank
      params[:release_multiview][:release_ids]=selected_ids(params[:release_multiview][:release_ids])
      @release_multiview.attributes = params[:release_multiview]

      if @release_multiview.save
        flash[:notice] = l(:notice_successful_create)
        redirect_to :controller => 'rb_releases', :action => 'index', :project_id => @project
      end
    end

  end

  def edit
    if request.post?
      # Convert id's into numbers and remove blank
      params[:release_multiview][:release_ids]=selected_ids(params[:release_multiview][:release_ids])

      if @release_multiview.update_attributes(params[:release_multiview])
        flash[:notice] = l(:notice_successful_update)
        redirect_to :controller => 'rb_releases_multiview', :action => 'show', :release_multiview_id => @release_multiview
      end
    end
  end

  def update
  end

  def destroy
    @release_multiview.destroy
    redirect_to :controller => 'rb_releases', :action => 'index', :project_id => @project
  end

end
