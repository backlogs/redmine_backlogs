include RbCommonHelper

class RbActivityController < RbApplicationController
  unloadable


  def show

    @activity = Redmine::Activity::Fetcher.new(User.current, :project => @project,
                                                             :author => nil)
    @activity.scope = (:default) 

    events = @activity.events(nil, nil, :limit => 20)
    @events_by_day = events.group_by(&:event_date)
    render :action => 'show', :layout => 'empty'

  rescue ActiveRecord::RecordNotFound
    render_404
  end
end
