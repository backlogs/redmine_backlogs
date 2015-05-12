include RbCommonHelper
include RbFormHelper
include ProjectsHelper

# Responsible for exposing release CRUD.
class RbReleasesController < RbApplicationController
  unloadable

  def index
    @releases_open = @project.open_releases_by_date
    @releases_closed = @project.closed_releases_by_date
    @releases_multiview = @project.releases_multiview
  end

  def show
    @remaining_story_points = @release.remaining_story_points

    respond_to do |format|
      format.html { render }
      format.csv  { send_data(release_burndown_to_csv(@release), :type => 'text/csv; header=present', :filename => 'export.csv') }
    end
  end

  def new
    @release = RbRelease.new
    @release.project = @project
  end

  def create
    @release = RbRelease.new(release_params)
    @release.project = @project
    if @release.save
      flash[:notice] = l(:notice_successful_create)
      redirect_to :action => 'index', :project_id => @project
    else
      render action: :new
    end
  end

  def edit
    if request.post? and @release.update_attributes(release_params)
      flash[:notice] = l(:notice_successful_update)
      redirect_to :controller => 'rb_releases', :action => 'show', :release_id => @release
#    else
#      flash[:notice] = l(:notice_unsuccessful_update)
    end
  end

  def update
    except = ['id', 'project_id']
    attribs = params.select{|k,v| (!except.include? k) and (RbRelease.column_names.include? k) }
    attribs = Hash[*attribs.flatten]
    begin
      result  = @release.update_attributes attribs
    rescue => e
      Rails.logger.debug e
      Rails.logger.debug e.backtrace.join("\n")
      render :text => e.message.blank? ? e.to_s : e.message, :status => 400
      return
    end

    respond_to do |format|
      format.html { render :partial => "release_mbp", :status => (result ? 200 : 400), :locals => { :release => @release, :cls => 'model release' } }
    end
  end

  def destroy
    @release.destroy
    redirect_to :controller => 'rb_releases', :action => 'index', :project_id => @project
  end

  private

  def release_params
    params.require(:release).permit(:name, :description, :status, :release_start_date, :release_end_date, :planned_velocity, :sharing)
  end

end
