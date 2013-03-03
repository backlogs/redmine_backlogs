class RbStory < Issue
  unloadable

  private

  def self.__find_options_normalize_option(option)
    option = [option] if option && !option.is_a?(Array)
    option = option.collect{|s| s.is_a?(Integer) ? s : s.id} if option
  end

  def self.__find_options_add_permissions(options)
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
  end

  def self.__find_options_sprint_condition(project_id, sprint_ids)
    if Backlogs.settings[:sharing_enabled]
      ["
        tracker_id in (?)
        and fixed_version_id IN (?)", self.trackers, sprint_ids]
    else
      ["
        project_id = ?
        and tracker_id in (?)
        and fixed_version_id IN (?)", project_id, self.trackers, sprint_ids]
    end
  end

  def self.__find_options_release_condition(project_id, release_ids)
    ["
      project_id in (#{Project.find(project_id).projects_in_shared_product_backlog.map{|p| p.id}.join(',')})
      and tracker_id in (?)
      and fixed_version_id is NULL
      and release_id in (?)", self.trackers, release_ids]
  end

  def self.__find_options_pbl_condition(project_id)
    ["
      project_id in (#{Project.find(project_id).projects_in_shared_product_backlog.map{|p| p.id}.join(',')})
      and tracker_id in (?)
      and release_id is NULL
      and fixed_version_id is NULL
      and is_closed = ?", self.trackers, false]
  end

  public

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

    self.__find_options_add_permissions(options)

    sprint_ids = self.__find_options_normalize_option(options.delete(:sprint))
    release_ids = self.__find_options_normalize_option(options.delete(:release))

    if sprint_ids
      Backlogs::ActiveRecord.add_condition(options, self.__find_options_sprint_condition(project_id, sprint_ids))
    elsif release_ids
      Backlogs::ActiveRecord.add_condition(options, self.__find_options_release_condition(project_id, release_ids))
    else #product backlog
      Backlogs::ActiveRecord.add_condition(options, self.__find_options_pbl_condition(project_id))
      options[:joins] ||= []
      options[:joins] [options[:joins]] unless options[:joins].is_a?(Array)
      options[:joins] << :status
      options[:joins] << :project
    end

    options
  end

  scope :backlog_scope, lambda{|opts| RbStory.find_options(opts) }

  def self.backlog(project_id, sprint_id, release_id, options={})
    stories = []

    prev = nil
    RbStory.visible.order("#{self.table_name}.position").
      backlog_scope(
        options.merge({ #FIXME visible is already contained in find_option???
          :project => project_id,
          :sprint => sprint_id,
          :release => release_id
      })).each_with_index {|story, i|
      stories << story

      #optimization: set virtual attributes to avoid hundreds of sql queries
      # this requires that the scope is clean - meaning exactly ONE backlog is queried here.
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
    #make separate queries for each sprint to get higher/lower item right
    sprint_of = {}
    sprints.each do |s|
      sprint_of[s.id] ||= []
      sprint_of[s.id] = RbStory.backlog(project.id, s.id, nil, options)
    end
    return sprint_of
  end

  def self.backlogs_by_release(project, releases, options={})
    #make separate queries for each release to get higher/lower item right
    release_of = {}
    releases.each do |r|
      release_of[r.id] ||= []
      release_of[r.id] = RbStory.backlog(project.id, nil, r.id, options)
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

  scope :updated_since, lambda {|since|
          where(["#{self.table_name}.updated_on > ?", Time.parse(since)]).
          order("#{self.table_name}.updated_on ASC")
        }

  def self.find_all_updated_since(since, project_id)
    #look in backlog, sprint and releases. look in shared sprints and shared releases
    project = Project.select("id,lft,rgt").find_by_id(project_id)
    sprints = project.open_shared_sprints.map{|s|s.id}
    releases = project.open_releases_by_date.map{|s|s.id}
    #following will execute 3 queries and join it as array
    self.backlog_scope( {:project => project_id, :sprint => nil, :release => nil } ).
          updated_since(since) |
      self.backlog_scope( {:project => project_id, :sprint => sprints, :release => nil } ).
          updated_since(since) |
      self.backlog_scope( {:project => project_id, :sprint => nil, :release => releases } ).
          updated_since(since)
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
        self.move_to_top # move after 'prev'. Meaning no prev, we go at top
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

  def list_with_gaps_scope_condition(options={})
    return options if self.new_record?
    self.class.find_options(options.dup.merge({
      :project => self.project_id,
      :sprint => self.fixed_version_id,
      :release => self.release_id
    }))
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
        avg_ratio = tasks.map{|task| task.status.default_done_ratio.to_f }.sum / tasks.length # #837 coerce to float, nil counts for 0.0
        #find status near avg_ratio
        #find the status allowed, order by position, with nearest default_done_ratio not higher then avg_ratio
        new_st = nil
        self.new_statuses_allowed_to.each{|status|
          new_st = status if status.default_done_ratio.to_f <= avg_ratio # #837 use to_f for comparison of number OR nil
          break if status.default_done_ratio.to_f > avg_ratio
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
