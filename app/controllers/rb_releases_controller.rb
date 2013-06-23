include RbCommonHelper
include RbFormHelper
include ProjectsHelper

# Responsible for exposing release CRUD.
class RbReleasesController < RbApplicationController
  unloadable

  def index
    @releases_open = @project.open_releases_by_date
    @releases_closed = @project.closed_releases_by_date
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

end
