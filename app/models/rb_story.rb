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

    if Backlogs.settings[:sharing_enabled]
      pbl_condition = ["
        (#{Project.find(project_id).project_condition(true)})
        and tracker_id in (?)
        and fixed_version_id is NULL
        and is_closed = ?", RbStory.trackers, false]
      sprint_condition = ["
        tracker_id in (?)
        and fixed_version_id IN (?)", RbStory.trackers, sprint_ids]
    else
      pbl_condition = ["
        project_id = ?
        and tracker_id in (?)
        and fixed_version_id is NULL
        and is_closed = ?", project_id, RbStory.trackers, false]
      sprint_condition = ["
        project_id = ?
        and tracker_id in (?)
        and fixed_version_id IN (?)", project_id, RbStory.trackers, sprint_ids]
    end

    if sprint_ids.nil?
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

  def self.backlog(project_id, sprint_id, options={})
    stories = []

    prev = nil
    RbStory.find(:all, RbStory.find_options(options.merge({
      :project => project_id,
      :sprint => sprint_id,
      :order => :position,
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
    return RbStory.backlog(project.id, nil, :limit => limit)
  end

  def self.sprint_backlog(sprint, options={})
    return RbStory.backlog(sprint.project.id, sprint.id, options)
  end

  def self.backlogs_by_sprint(project, sprints, options={})
    ret = RbStory.backlog(project.id, sprints.map {|s| s.id }, options)
    sprint_of = {}
    ret.each do |backlog|
      sprint_of[backlog.fixed_version_id] ||= []
      sprint_of[backlog.fixed_version_id].push(backlog)
    end
    return sprint_of
  end

  def self.stories_open(project)
    stories = []

    RbStory.find(:all,
                  :order => :position,
                  :conditions => ["project_id = ? AND tracker_id in (?) and is_closed = ?",project.id,RbStory.trackers,false],
                  :joins => :status).each_with_index {|story, i|
      story.rank = i + 1
      stories << story
    }
    return stories
  end

  def self.create_and_position(params)
    params['prev'] = params.delete('prev_id') if params.include?('prev_id')
    params['next'] = params.delete('next_id') if params.include?('next_id')

    # lft and rgt fields are handled by acts_as_nested_set
    attribs = params.select{|k,v| !['prev', 'id', 'lft', 'rgt'].include?(k) && RbStory.column_names.include?(k) }
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
    return RbTask.tasks_for(self.id)
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

  def burndown(sprint=nil)
    return nil unless self.is_story?
    sprint ||= self.fixed_version.becomes(RbSprint) if self.fixed_version
    return nil if sprint.nil? || !sprint.has_burndown?

    return Rails.cache.fetch("RbIssue(#{self.id}@#{self.updated_on}).burndown(#{sprint.id}@#{sprint.updated_on}-#{[Date.today, sprint.effective_date].min})") {
      bd = {}

      if sprint.has_burndown?
        days = sprint.days(:active)

        series = Backlogs::MergedArray.new
        series.merge(:in_sprint => history(:fixed_version_id, days).collect{|s| s == sprint.id})
        series.merge(:points => history(:story_points, days))
        series.merge(:open => history(:status_open, days))
        series.merge(:accepted => history(:status_success, days))
        series.merge(:hours => ([0] * (days.size + 1)))

        tasks.each{|task| series.add(:hours => task.burndown(sprint)) }

        series.each {|datapoint|
          if datapoint.in_sprint
            datapoint.hours = 0 unless datapoint.open
            datapoint.points_accepted = (datapoint.accepted ? datapoint.points : nil)
            datapoint.points_resolved = (datapoint.accepted || datapoint.hours.to_f == 0.0 ? datapoint.points : nil)
          else
            datapoint.nilify
            datapoint.points_accepted = nil
            datapoint.points_resolved = nil
          end
        }

        # collect points on this sprint
        bd[:points] = series.series(:points)
        bd[:points_accepted] = series.series(:points_accepted)
        bd[:points_resolved] = series.series(:points_resolved)
        bd[:hours] = series.collect{|datapoint| datapoint.open ? datapoint.hours : nil}
      end

      bd
    }
  end

  def rank
    return super(RbStory.find_options(:project => self.project_id, :sprint => self.fixed_version_id))
  end

end
