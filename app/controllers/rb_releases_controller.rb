include RbCommonHelper

# Responsible for exposing release CRUD.
class RbReleasesController < RbApplicationController
  unloadable

  def index
    @releases = Release.find(:all, :conditions => { :project_id => @project })
  end

  def show
    @remaining_story_points = remaining_story_points

    respond_to do |format|
      format.html { render }
      format.csv  { send_data(release_burndown_to_csv(@release), :type => 'text/csv; header=present', :filename => 'export.csv') }
    end
  end

  def new
    @release = Release.new(:project => @project)
    @backlog_points = remaining_story_points
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
      @backlog_points = remaining_story_points
    end
  end

  def destroy
    @release.destroy
    redirect_to :controller => 'rb_releases', :action => 'index', :project_id => @project
  end

  def snapshot
    rbdd = @release.today
    unless rbdd
      rbdd = ReleaseBurndownDay.new
      rbdd.release_id = @release.id
      rbdd.day = Date.today
    end
    rbdd.remaining_story_points = remaining_story_points
    rbdd.save!
    redirect_to :controller => 'rb_releases', :action => 'show', :release_id => @release
  end

  private

  def remaining_story_points
    res = 0
    @release.stories.each {|s| res += s.story_points if s.story_points}
    res
  end
  
end
