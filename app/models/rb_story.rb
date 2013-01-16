class RbStory < Issue
  unloadable

  def self.find_options(options)
    options = options.dup

    project = options.delete(:project)
    if project.nil?
      project_id = nil
    elsif project.is_a?(Integer)
      project_id = project
      project = nil
    else
      project_id = project.id
    end

    sprint_ids = options.delete(:sprint)
    sprint_ids = [sprint_ids] if sprint_ids && !sprint_ids.is_a?(Array)
    sprint_ids = sprint_ids.collect{|s| s.is_a?(Integer) ? s : s.id} if sprint_ids

    release_ids = options.delete(:release)
    release_ids = [release_ids] if release_ids && !release_ids.is_a?(Array)
    release_ids = release_ids.collect{|s| s.is_a?(Integer) ? s : s.id} if release_ids

    permission = options.delete(:permission)
    permission = false if permission.nil?

    options[:conditions] ||= []

    if permission
      if Issue.respond_to? :visible_condition
        visible = Issue.visible_condition(User.current, :project => project || Project.find(project_id))
      else
    	  visible = Project.allowed_to_condition(User.current, :view_issues)
      end
      Backlogs::ActiveRecord.add_condition(options, visible)
    end

    pbl_condition = ["
      project_id in (#{Project.find(project_id).projects_in_shared_product_backlog.map{|p| p.id}.join(',')})
      and tracker_id in (?)
      and release_id is NULL
      and fixed_version_id is NULL
      and is_closed = ?", RbStory.trackers, false]
    if Backlogs.settings[:sharing_enabled]
      sprint_condition = ["
        tracker_id in (?)
        and fixed_version_id IN (?)", RbStory.trackers, sprint_ids]
    else
      sprint_condition = ["
        project_id = ?
        and tracker_id in (?)
        and fixed_version_id IN (?)", project_id, RbStory.trackers, sprint_ids]
    end
    release_condition = ["
      project_id in (#{Project.find(project_id).projects_in_shared_product_backlog.map{|p| p.id}.join(',')})
      and tracker_id in (?)
      and fixed_version_id is NULL
      and release_id in (?)", RbStory.trackers, release_ids]

    if release_ids
      Backlogs::ActiveRecord.add_condition(options, release_condition)
    elsif sprint_ids.nil?
      Backlogs::ActiveRecord.add_condition(options, pbl_condition)
      options[:joins] ||= []
      options[:joins] [options[:joins]] unless options[:joins].is_a?(Array)
      options[:joins] << :status
      options[:joins] << :project
    else
      Backlogs::ActiveRecord.add_condition(options, sprint_condition)
    end

    return options
  end

  def self.backlog(project_id, sprint_id, release_id, options={})
    stories = []

    prev = nil
    RbStory.visible.find(:all, RbStory.find_options(options.merge({
      :project => project_id,
      :sprint => sprint_id,
      :release => release_id,
      :order => 'issues.position'
    }))).each_with_index {|story, i|
      stories << story

      prev.higher_item = story if prev
      story.lower_item = prev

      story.rank = i + 1

      prev = story
    }

    return stories
  end

  def self.product_backlog(project, limit=nil)
    return RbStory.backlog(project.id, nil, nil, :limit => limit)
  end

  def self.sprint_backlog(sprint, options={})
    return RbStory.backlog(sprint.project.id, sprint.id, nil, options)
  end

  def self.release_backlog(release, options={})
    return RbStory.backlog(release.project.id, nil, release.id, options)
  end

  def self.backlogs_by_sprint(project, sprints, options={})
    ret = RbStory.backlog(project.id, sprints.map {|s| s.id }, nil, options)
    sprint_of = {}
    ret.each do |backlog|
      sprint_of[backlog.fixed_version_id] ||= []
      sprint_of[backlog.fixed_version_id].push(backlog)
    end
    return sprint_of
  end

  def self.backlogs_by_release(project, releases, options={})
    ret = RbStory.backlog(project.id, nil, releases.map {|s| s.id }, options)
    release_of = {}
    ret.each do |backlog|
      release_of[backlog.release_id] ||= []
      release_of[backlog.release_id].push(backlog)
    end
    return release_of
  end

  def self.create_and_position(params)
    params['prev'] = params.delete('prev_id') if params.include?('prev_id')
    params['next'] = params.delete('next_id') if params.include?('next_id')
    params['prev'] = nil if (['next', 'prev'] - params.keys).size == 2

    # lft and rgt fields are handled by acts_as_nested_set
    attribs = params.select{|k,v| !['prev', 'next', 'id', 'lft', 'rgt'].include?(k) && RbStory.column_names.include?(k) }
    attribs = Hash[*attribs.flatten]
    s = RbStory.new(attribs)
    s.save!
    s.position!(params)

    return s
  end

  def self.find_all_updated_since(since, project_id)
    find(:all,
          :conditions => ["project_id = ? AND updated_on > ? AND tracker_id in (?)", project_id, Time.parse(since), trackers],
          :order => "updated_on ASC")
  end

  def self.trackers(options = {})
    # legacy
    options = {:type => options} if options.is_a?(Symbol)

    # somewhere early in the initialization process during first-time migration this gets called when the table doesn't yet exist
    trackers = []
    if has_settings_table
      trackers = Backlogs.setting[:story_trackers]
      trackers = [] if trackers.blank?
    end

    trackers = Tracker.find_all_by_id(trackers)
    trackers = trackers & options[:project].trackers if options[:project]
    trackers = trackers.sort_by { |t| [t.position] }

    case options[:type]
      when :trackers      then return trackers
        when :array, nil  then return trackers.collect{|t| t.id}
        when :string      then return trackers.collect{|t| t.id.to_s}.join(',')
        else                   raise "Unexpected return type #{options[:type].inspect}"
    end
  end

  def self.has_settings_table
    ActiveRecord::Base.connection.tables.include?('settings')
  end

  def tasks
    return self.children
  end

  def set_points(p)
    return self.journalized_update_attribute(:story_points, nil) if p.blank? || p == '-'

    return self.journalized_update_attribute(:story_points, 0) if p.downcase == 's'

    return self.journalized_update_attribute(:story_points, Float(p)) if Float(p) >= 0
  end

  def points_display(notsized='-')
    # For reasons I have yet to uncover, activerecord will
    # sometimes return numbers as Fixnums that lack the nil?
    # method. Comparing to nil should be safe.
    return notsized if story_points == nil || story_points.blank?
    return 'S' if story_points == 0
    return story_points.to_s
  end

  def update_and_position!(params)
    params['prev'] = params.delete('prev_id') if params.include?('prev_id')
    params['next'] = params.delete('next_id') if params.include?('next_id')
    self.position!(params)

    # lft and rgt fields are handled by acts_as_nested_set
    attribs = params.select{|k,v| !['prev', 'id', 'project_id', 'lft', 'rgt'].include?(k) && RbStory.column_names.include?(k) }
    attribs = Hash[*attribs.flatten]

    return self.journalized_update_attributes attribs
  end

  def position!(params)
    if params.include?('prev')
      if params['prev'].blank?
        self.move_to_top
      else
        self.move_after(RbStory.find(params['prev']))
      end
    elsif params.include?('next')
      if params['next'].blank?
        self.move_to_bottom
      else
        self.move_before(RbStory.find(params['next']))
      end
    end
  end

  # Produces relevant information for release graphs
  # @param sprints is array of sprints of interest
  # @return hash collection of 
  #  :backlog_points :added_points :closed_points
# The dates are:
#  start: first day of first sprint
#  1..n: a day after the nth sprint
  def release_burndown_data(sprints)
    return nil unless self.is_story?
    days = Array.new
    # Find interesting days of each sprint for the release graph
    days << sprints.first.sprint_start_date.to_date
    sprints.each { |sprint| days << sprint.effective_date.tomorrow.to_date }

    baseline = [0] * days.size

    series = Backlogs::MergedArray.new
    series.merge(:backlog_points => baseline.dup)
    series.merge(:added_points => baseline.dup)
    series.merge(:closed_points => baseline.dup)

    # Collect data
    bd = {:points => [], :open => [], :accepted => [] }
    self.history.filter_release(days).each{|d|
      if d.nil? || d[:tracker] != :story
        [:points, :open, :accepted].each{|k| bd[k] << nil }
      else
        bd[:points] << d[:story_points]
        bd[:open] << d[:status_open]
        bd[:accepted] << d[:status_success] #What do do with rejected points? The story is not open anymore.
      end
    }

    series.merge(:accepted => bd[:accepted])
    series.merge(:points => bd[:points])
    series.merge(:open => bd[:open])
    first = true;
    series.merge(:accepted_first => series.series(:accepted).collect{ |a|
                   if a
                     if a == true && first == true
                       first = false
                       true
                     else
                       false
                     end
                   else
                     false
                   end
                 })
    series.merge(:day => days)

    # Extract added_points, backlog_points and closed points from the data collected
    series.each { |p|
      if (created_on.to_date < sprints.first.sprint_start_date.to_date) && p.open
        p.backlog_points = p.points
      end
      if p.accepted_first
        p.closed_points = p.points
      end
      # Is the story created within this sprint?
      if (created_on.to_date >= sprints.first.sprint_start_date.to_date) &&
          (created_on.to_date < p.day) #day is the end-date+1 of a sprint
        p.added_points = p.points
        if p.accepted
          p.backlog_points = -p.points
        end
      end
    }

    rl = {}
    rl[:backlog_points] = series.series(:backlog_points)
    rl[:added_points] = series.series(:added_points)
    rl[:closed_points] = series.series(:closed_points)
    return rl
  end

  def burndown(sprint = nil, status=nil)
    return nil unless self.is_story?
    sprint ||= self.fixed_version.becomes(RbSprint) if self.fixed_version
    return nil if sprint.nil? || !sprint.has_burndown?

    bd = {:points_committed => [], :points_accepted => [], :points_resolved => [], :hours_remaining => []}

    self.history.filter(sprint, status).each{|d|
      if d.nil? || d[:sprint] != sprint.id || d[:tracker] != :story
        [:points_committed, :points_accepted, :points_resolved, :hours_remaining].each{|k| bd[k] << nil}
      else
        bd[:points_committed] << d[:story_points]
        bd[:points_accepted] << (d[:status_success] ? d[:story_points] : 0)
        bd[:points_resolved] << (d[:status_success] || d[:hours].to_f == 0.0 ? d[:story_points] : 0)
        bd[:hours_remaining] << (d[:status_closed] ? 0 : d[:hours])
      end
    }
    return bd
  end

  def rank
    return super(RbStory.find_options(:project => self.project_id, :sprint => self.fixed_version_id))
  end

  def story_follow_task_state
    return if Setting.plugin_redmine_backlogs[:story_follow_task_status] != 'close' && Setting.plugin_redmine_backlogs[:story_follow_task_status] != 'loose'
    return if self.status.is_closed? #bail out if we are closed

    self.reload #we might be stale at this point
    case Setting.plugin_redmine_backlogs[:story_follow_task_status]
      when 'close'
        set_closed_status_if_following_to_close
      when 'loose'
        avg_ratio = tasks.map{|task| task.status.default_done_ratio }.sum / tasks.length
        #find status near avg_ratio
        #find the status allowed, order by position, with nearest default_done_ratio not higher then avg_ratio
        new_st = nil
        self.new_statuses_allowed_to.each{|status|
          new_st = status if status.default_done_ratio <= avg_ratio
          break if status.default_done_ratio > avg_ratio
        }
        #set status and good.
        self.journalized_update_attributes :status_id => new_st.id if new_st
        set_closed_status_if_following_to_close

        #calculate done_ratio weighted from tasks
        recalculate_attributes_for(self.id) unless Issue.use_status_for_done_ratio?
      else

    end
  end

  def set_closed_status_if_following_to_close
        status_id = Setting.plugin_redmine_backlogs[:story_close_status_id]
        unless status_id.nil? || status_id.to_i == 0
          # bail out if something is other than closed.
          tasks.each{|task| 
            return unless task.status.is_closed?
          }
          self.journalized_update_attributes :status_id => status_id.to_i #update, but no need to position
        end
  end
end
