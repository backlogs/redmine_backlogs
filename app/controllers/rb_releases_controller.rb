include RbCommonHelper
include RbFormHelper
include ProjectsHelper

# Responsible for exposing release CRUD.
class RbReleasesController < RbApplicationController
  unloadable

  def index
    @releases = RbRelease.find(:all, :conditions => { :project_id => @project })
  end

  def show
    @remaining_story_points = @release.remaining_story_points

    respond_to do |format|
      format.html { render }
      format.csv  { send_data(release_burndown_to_csv(@release), :type => 'text/csv; header=present', :filename => 'export.csv') }
    end
  end

  def new
    @release = RbRelease.new(:project => @project)
    @backlog_points = @release.remaining_story_points
    @release.initial_story_points = @backlog_points
    if request.post?
      @release.attributes = params[:release]
      if @release.save
        flash[:notice] = l(:notice_successful_create)
        redirect_to :action => 'index', :project_id => @project
      end
    end
  end

  def edit
    if request.post? and @release.update_attributes(params[:release])
      flash[:notice] = l(:notice_successful_update)
      redirect_to :controller => 'rb_releases', :action => 'show', :release_id => @release
    else
      @backlog_points = @release.remaining_story_points
    end
  end

  def destroy
    @release.destroy
    redirect_to :controller => 'rb_releases', :action => 'index', :project_id => @project
  end

  def snapshot
    @release.snapshot!
    redirect_to :controller => 'rb_releases', :action => 'show', :release_id => @release
  end

end
