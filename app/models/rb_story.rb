class RbStory < Issue
  unloadable

  acts_as_list

  POSITION_GAP = 50

  def self.condition(project_id, sprint_id, extras=[])
    if Issue.respond_to? :visible_condition
      visible = Issue.visible_condition(User.current, :project => Project.find(project_id))
    else
    	visible = Project.allowed_to_condition(User.current, :view_issues)
    end
    visible = '1=1' # unless visible

    if sprint_id.nil?
      c = ["
        project_id = ?
        and tracker_id in (?)
        and fixed_version_id is NULL
        and is_closed = ? and #{visible}", project_id, RbStory.trackers, false]
    else
      unless sprint_id.kind_of? Array
          sprint_id = [ sprint_id ]
      end
      c = ["
        project_id = ?
        and tracker_id in (?)
        and fixed_version_id IN (?) and #{visible}",
        project_id, RbStory.trackers, sprint_id]
    end

    if extras.size > 0
      c[0] += ' ' + extras.shift
      c += extras
    end

    return c
  end

  # this forces NULLS-LAST ordering
  ORDER = 'case when issues.position is null then 1 else 0 end ASC, case when issues.position is NULL then issues.id else issues.position end ASC'

  def self.backlog(project_id, sprint_id, options={})
    stories = []

    RbStory.find(:all,
                  :order => RbStory::ORDER,
                  :conditions => RbStory.condition(project_id, sprint_id),
                  :joins => [:status, :project],
                  :limit => options[:limit]).each_with_index {|story, i|
      story.rank = i + 1
      stories << story
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
                  :order => RbStory::ORDER,
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
    s.save!
    s.move_after(params['prev_id'])
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

  def move_after(prev_id)
    if prev_id.to_s == ''
      prev = nil
    else
      begin
        prev = RbStory.find(prev_id)
      rescue ActiveRecord::RecordNotFound
        prev = nil
      end
    end

    conn = RbStory.connection

    if prev.nil?
      self.position = (RbStory.minimum(:position) || RbStory::POSITION_GAP) - RbStory::POSITION_GAP
    else
      begin
        nxt = RbStory.find(:first, :conditions => ['position > ?', prev.position], :order => :position)
      rescue ActiveRecord::RecordNotFound
        nxt = nil
      end

      if nxt.nil?
        self.position = prev.position + RbStory::POSITION_GAP
      else
        if (nxt.position - prev.position) < 2
          RbStory.transaction do
            conn.execute("update issues set position_lock = position where position > #{prev.position}") # damn you MySQL
            conn.execute("update issues set position = position + #{RbStory::POSITION_GAP} where position > #{prev.position}") # make a gap
            conn.execute('update issues set position_lock = 0 where position_lock <> 0') # damn you MySQL
            nxt.position += RbStory::POSITION_GAP
          end
        end

        self.position = (prev.position + nxt.position) / 2
      end
    end

    conn.execute("update issues set position = #{self.position} where id=#{self.id}")
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
    result = self.journalized_batch_update_attributes attribs
    move_after(params[:prev]) if result and params[:prev]
    return result
  end

  def rank=(r)
    @rank = r
  end

  def rank
    @rank ||= Issue.count(:conditions => RbStory.condition(self.project.id, self.fixed_version_id, ['and issues.position <= ?', self.position]), :joins => [:status, :project])

    return @rank
  end

  def self.at_rank(project_id, sprint_id, rank)
    return RbStory.find(:first,
                        :order => RbStory::ORDER,
                        :conditions => RbStory.condition(project_id, sprint_id),
                        :joins => [:status, :project],
                        :limit => 1,
                        :offset => rank - 1)
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

  def higher_item
    begin
      return RbStory.find(:first, :conditions => ['position < ?', self.position], :order => "position DESC")
    rescue ActiveRecord::RecordNotFound
      return nil
    end
  end

  def lower_item
    begin
      return RbStory.find(:first, :conditions => ['position > ?', self.position], :order => :position)
    rescue ActiveRecord::RecordNotFound
      return nil
    end
  end

#  def first?
#    RbStory.find(:first, :conditions => "position = (select min(position)) from issues")
#  end

#  def last?
#    RbStory.find(:first, :conditions => "position = (select max(position)) from issues")
#  end

end
