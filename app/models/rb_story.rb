class RbStory < Issue
    unloadable

    acts_as_list

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
      attribs = params.select{|k,v| k != 'prev_id' and k != 'id' and RbStory.column_names.include? k }
      attribs = Hash[*attribs.flatten]
      s = RbStory.new(attribs)
      s.save!
      # indicate that this a new story. saving will set position to 1 and the move_after code needs position = nil to make an insert operation.
      s.position = nil
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
        when :trackers
          return trackers
        when :array, nil
          return trackers.collect{|t| t.id}
        when :string
          return trackers.collect{|t| t.id.to_s}.join(',')
        else
          raise "Unexpected return type #{options[:type].inspect}"
      end
    end

    def tasks
      return RbTask.tasks_for(self.id)
    end

    def move_after(prev_id)
      # remove so the potential 'prev' has a correct position
      RbStory.connection.execute("update issues set position = position - 1 where position > #{position}") unless position.nil?

      if prev_id.to_s == ''
        prev = nil
      else
        prev = RbStory.find(prev_id)
      end

      # if prev is the first story, move current to the 1st position
      if prev.blank?
        RbStory.connection.execute("update issues set position = position + 1")
        # stories do start at position 0
        RbStory.connection.execute("update issues set position = 0 where id = #{id}")

      # if its predecessor has no position (shouldn't happen
      # - but happens if we add many stories using "new issues" and begin sorting),
      # make current the last positioned story the last story
      elsif prev.position.nil?
        new_pos = 0
        RbStory.connection.execute("select coalesce(max(position)+1, 0) from issues").each{|row|
          row = row.values if row.is_a?(Hash)
          new_pos = row[0]
        }
        RbStory.connection.execute("update issues set position = #{new_pos} where id = #{id}")

      # there's a valid predecessor
      else
        RbStory.connection.execute("update issues set position = position + 1 where position > #{prev.position}")
        RbStory.connection.execute("update issues set position = #{prev.position} + 1 where id = #{id}")

      end
    end

    def set_points(p)
        self.init_journal(User.current)

        if p.blank? || p == '-'
            self.update_attribute(:story_points, nil)
            return
        end

        if p.downcase == 's'
            self.update_attribute(:story_points, 0)
            return
        end

        p = Integer(p)
        if p >= 0
            self.update_attribute(:story_points, p)
            return
        end
    end

    def points_display(notsized='-')
        # For reasons I have yet to uncover, activerecord will
        # sometimes return numbers as Fixnums that lack the nil?
        # method. Comparing to nil should be safe.
        return notsized if story_points == nil || story_points.blank?
        return 'S' if story_points == 0
        return story_points.to_s
    end

    def task_status
        closed = 0
        open = 0
        self.descendants.each {|task|
            if task.closed?
                closed += 1
            else
                open += 1
            end
        }
        return {:open => open, :closed => closed}
    end

    def update_and_position!(params)
      attribs = params.select{|k,v| k != 'id' && k != 'project_id' && RbStory.column_names.include?(k) }
      attribs = Hash[*attribs.flatten]
      result = self.becomes(Issue).journalized_update_attributes attribs
      if result and params[:prev]
        move_after(params[:prev])
      end
      result
    end

  def rank=(r)
    @rank = r
  end

  def rank
    if self.position.blank?
      extras = ['and ((issues.position is NULL and issues.id <= ?) or not issues.position is NULL)', self.id]
    else
      extras = ['and not issues.position is NULL and issues.position <= ?', self.position]
    end

    @rank ||= Issue.count(:conditions => RbStory.condition(self.project.id, self.fixed_version_id, extras), :joins => [:status, :project])

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

  # Produces relevant information for release graphs
  # @param sprints is array of sprints of interest
  # @return hash collection of 
  def release(sprints)
    days = Array.new
    # Find interesting days of each sprint for the release graph
    sprints.each { |sprint| days << sprint.sprint_start_date.to_date }
#TODO Maybe only effective_date??
    days_end = days.dup
    days_end.shift
    days_end << sprints.last.effective_date.to_date
    status = history(:status_id,days,false).collect{|s| s ? IssueStatus.find(s) : nil}[0...-1]
    baseline = [0] * days.size

    series = Backlogs::MergedArray.new
    series.merge(:backlog_points => baseline.dup)
    series.merge(:added_points => baseline.dup)
    series.merge(:closed_points => baseline.dup)

    # Collect data
    series.merge(:accepted => status.collect{|s| s ? (s.backlog_is?(:success)) : false})
    series.merge(:points => history(:story_points,days,false)[0...-1])
    series.merge(:open => status.collect{|s| s ? !s.is_closed? : false})
    first = true;
    series.merge(:accepted_first => status.collect{|s|
                   if s
                     if s.backlog_is?(:success) && first == true
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
    series.merge(:day_end => days_end)

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
          (created_on.to_date < p.day_end)
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

end
