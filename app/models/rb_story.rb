class RbStory < Issue
  unloadable

  acts_as_list_with_gaps

<<<<<<< HEAD
  def self.find_params(options)
    project_id = options.delete(:project_id)
    sprint_ids = options.delete(:sprint_id)
    include_backlog = options.delete(:include_backlog)

    sprint_ids = RbSprint.open_sprints(Project.find(project_id)).collect{|s| s.id} if project_id && sprint_ids == :open

    project_id = nil if !include_backlog && sprint_ids
    sprint_ids = [sprint_ids] if sprint_ids && !sprint_ids.is_a?(Array)

    raise "Specify either sprint or project id" unless (sprint_ids || project_id)

    options[:joins] = [options[:joins]] unless options[:joins].is_a?(Array)

    conditions = []
    parameters = []
    options[:joins] << :project

    if project_id
      conditions << "(tracker_id in (?) and fixed_version_id is NULL and #{IssueStatus.table_name}.is_closed = ? and (#{Project.find(project_id).project_condition(true)}))"
      parameters += [RbStory.trackers, false]
      options[:joins] << :status
    end

    if sprint_ids
      conditions << "(tracker_id in (?) and fixed_version_id in (?))"
      parameters += [RbStory.trackers, sprint_ids]
    end

    conditions = conditions.join(' or ')

    visible = []
    visible = sprint_ids.collect{|s| Issue.visible_condition(User.current, :project => Version.find(s).project, :with_subprojects => true) } if sprint_ids
    visible << Issue.visible_condition(User.current, :project => Project.find(project_id), :with_subprojects => true) if project_id
    visible = visible.join(' or ')
    visible = " and (#{visible})" unless visible == ''

    conditions += visible

    options[:conditions] = [options[:conditions]] if options[:conditions] && !options[:conditions].is_a?(Array)
    if options[:conditions]
      conditions << " and (" + options[:conditions].delete_at(0) + ")"
      parameters += options[:conditions]
    end

    options[:conditions] = [conditions] + parameters

    options[:joins].compact!
    options[:joins].uniq!
    options.delete(:joins) if options[:joins].size == 0

    return options
  end

  # this forces NULLS-LAST ordering
  ORDER = 'case when issues.position is null then 1 else 0 end ASC, case when issues.position is NULL then issues.id else issues.position end ASC'

  def self.backlog(options={})
    stories = []
    RbStory.find(:all, RbStory.find_params(options.merge(:order => RbStory::ORDER))).each_with_index {|story, i|
      story.rank = i + 1
=======
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

    if sprint_ids.nil?
      Backlogs::ActiveRecord.add_condition(options, ["
        project_id = ?
        and tracker_id in (?)
        and fixed_version_id is NULL
        and is_closed = ?", project_id, RbStory.trackers, false])
      options[:joins] ||= []
      options[:joins] [options[:joins]] unless options[:joins].is_a?(Array)
      options[:joins] << :status
      options[:joins] << :project
    else
      Backlogs::ActiveRecord.add_condition(options, ["
        project_id = ?
        and tracker_id in (?)
        and fixed_version_id IN (?)", project_id, RbStory.trackers, sprint_ids])
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
>>>>>>> master
      stories << story

      prev.higher_item = story if prev
      story.lower_item = prev

      story.rank = i + 1

      prev = story
    }

    return stories
  end

  def self.product_backlog(project, limit=nil)
    return RbStory.backlog(:project_id => project.id, :limit => limit)
  end

  def self.sprint_backlog(sprint, options={})
    return RbStory.backlog(options.merge(:sprint_id => sprint.id))
  end

  def self.backlogs_by_sprint(project, sprints, options={})
    ret = RbStory.backlog(options.merge(:project_id => project.id, :sprint_id => sprints.map {|s| s.id}))
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
    attribs = params.select{|k,v|
      k != 'prev_id' and
      k != 'id' and
      RbStory.column_names.include? k
    }
    # lft and rgt fields are handled by acts_as_nested_set
    attribs = attribs.select{|k,v| k != 'lft' and k != 'rgt'}
    attribs = Hash[*attribs.flatten]
    s = RbStory.new(attribs)
    s.move_after(RbStory.find(params['prev_id']), :commit => false) if params['prev_id']
    s.save!
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
    if ActiveRecord::Base.connection.tables.include?('settings')
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
    attribs = params.select{|k,v| k != 'id' && k != 'project_id' && RbStory.column_names.include?(k) }
    # lft and rgt fields are handled by acts_as_nested_set
    attribs = attribs.select{|k,v| k != 'lft' and k != 'rgt'}
    attribs = Hash[*attribs.flatten]
<<<<<<< HEAD
    result = self.journalized_batch_update_attributes attribs
    move_after(params[:prev]) if result and params[:prev]
    return result
  end

  def rank=(r)
    @rank = r
  end

  def rank
    @rank ||= Issue.count(RbStory.find_params(
      :sprint_id => self.fixed_version_id,
      :project_id => self.project.id,
      :conditions => ['issues.position <= ?', self.position]))

    return @rank
  end

  def self.at_rank(rank, options)
    return RbStory.find(:first, RbStory.find_params(options.merge(
                      :order => RbStory::ORDER,
                      :limit => 1,
                      :offset => rank - 1)))
=======
    # don't need to save the move_after since the batch_update will do so
    move_after(RbStory.find(params[:prev]), :commit => false) if params[:prev]
    return self.journalized_batch_update_attributes attribs
>>>>>>> master
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
