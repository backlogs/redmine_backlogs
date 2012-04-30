include RbCommonHelper

class RbTaskboardsController < RbApplicationController
  unloadable

  def show
    stories = @sprint.stories
    @story_ids    = stories.map{|s| s.id}

    @settings = Backlogs.settings

    ## determine status columns to show
    tracker = Tracker.find_by_id(RbTask.tracker)
    statuses = tracker.issue_statuses
    # disable columns by default
    if User.current.admin?
      @statuses = statuses
    else
      enabled = {}
      statuses.each{|s| enabled[s.id] = false}
      # enable all statuses held by current tasks, regardless of whether the current user has access
      RbTask.find(:all, :conditions => ['fixed_version_id = ?', @sprint.id]).each {|task| enabled[task.status_id] = true }

      roles = User.current.roles_for_project(@project)
      #@transitions = {}
      statuses.each {|status|

        # enable all statuses the current user can reach from any task status
        [false, true].each {|creator|
          [false, true].each {|assignee|

            allowed = status.new_statuses_allowed_to(roles, tracker, creator, assignee).collect{|s| s.id}
            #@transitions["c#{creator ? 'y' : 'n'}a#{assignee ? 'y' : 'n'}"] = allowed
            allowed.each{|s| enabled[s] = true}
          }
        }
      }
      @statuses = statuses.select{|s| enabled[s.id]}
    end

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
