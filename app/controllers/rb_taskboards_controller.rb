include RbCommonHelper

class RbTaskboardsController < RbApplicationController
  unloadable
  
  def show
    @statuses     = Tracker.find_by_id(RbTask.tracker).issue_statuses
    @story_ids    = @sprint.stories.map{|s| s.id}

    if @sprint.stories.size == 0
      @last_updated = nil
    else
      @last_updated = RbTask.find(:first,
                        :conditions => ['tracker_id = ? and fixed_version_id = ?', RbTask.tracker, @sprint.stories[0].fixed_version_id],
                        :order      => "updated_on DESC")
    end

    respond_to do |format|
      format.html { render :layout => "rb" }
    end
  end
  
end
