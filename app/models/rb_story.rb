class RbStory < Issue
    unloadable

    acts_as_list

    def self.condition(project_id, sprint_id, extras=[])
      if sprint_id.nil?  
        c = ["
          project_id = ?
          and tracker_id in (?)
          and fixed_version_id is NULL
          and is_closed = ?", project_id, RbStory.trackers, false]
      else
        c = ["
          project_id = ?
          and tracker_id in (?)
          and fixed_version_id = ?",
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
            :joins => :status,
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
      s.move_after(params['prev_id'])
      return s
    end

    def self.find_all_updated_since(since, project_id)
      find(:all,
           :conditions => ["project_id = ? AND updated_on > ? AND tracker_id in (?)", project_id, Time.parse(since), trackers],
           :order => "updated_on ASC")
    end

    def self.trackers(type = :array)
      # somewhere early in the initialization process during first-time migration this gets called when the table doesn't yet exist
      return [] unless ActiveRecord::Base.connection.tables.include?('settings')

      trackers = Setting.plugin_redmine_backlogs[:story_trackers]
      return [] if trackers.blank?

      return trackers.join(',') if type == :string

      return trackers.map { |tracker| Integer(tracker) }
    end

    def tasks
      return RbTask.tasks_for(self.id)
    end

    def move_after(prev_id)
      # remove so the potential 'prev' has a correct position
      remove_from_list

      if prev_id.to_s == ''
        prev = nil
      else
        prev = RbStory.find(prev_id)
      end

      # if it's the first story, move it to the 1st position
      if prev.blank?
        insert_at
        move_to_top

      # if its predecessor has no position (shouldn't happen), make it
      # the last story
      elsif !prev.in_list?
        insert_at
        move_to_bottom

      # there's a valid predecessor
      else
        insert_at(prev.position + 1)
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

    def relative_priority_display(notsized='-')
      return notsized if (relative_gain == nil || relative_gain.blank?) && (relative_penalty == nil || relative_penalty.blank?) && (relative_risk == nil || relative_risk.blank?) && (story_points == nil || story_points.blank?)
      return 'S' if relative_gain == 0 && relative_penalty == 0 && relative_risk == 0 && story_points == 0
      gain = Integer(relative_gain)
      penalty = Integer(relative_penalty)
      stp = Integer(story_points)
      risk = Integer(relative_risk)
      return ((gain.to_f + penalty.to_f) / (stp.to_f + risk.to_f)).to_f.round(2).to_s
      #return (relative_gain.to_f + relative_penalty.to_f) / (story_points.to_f + relative_risk.to_f).to_s
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
      attribs = params.select{|k,v| k != 'id' and RbStory.column_names.include? k }
      attribs = Hash[*attribs.flatten]
      result = journalized_update_attributes attribs
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

    @rank ||= Issue.count(:conditions => RbStory.condition(self.project.id, self.fixed_version_id, extras), :joins => :status)

    return @rank
  end

  def self.at_rank(project_id, sprint_id, rank)
    return RbStory.find(:first,
                      :order => RbStory::ORDER,
                      :conditions => RbStory.condition(project_id, sprint_id),
                      :joins => :status,
                      :limit => 1,
                      :offset => rank - 1)
  end

  def burndown(sprint=nil)
    unless @burndown
      sprint ||= fixed_version.becomes(RbSprint)

      if sprint
        @burndown = {}
        days = sprint.days(:active)

        status = history(:status_id, days).collect{|s| s ? IssueStatus.find(s) : nil}
        accepted = status.collect{|s| s ? (s.backlog == :accepted) : false}
        active = status.collect{|s| s ? !s.is_closed? : false}
        in_sprint = history(:fixed_version_id, days).collect{|s| s == sprint.id}

        # collect points on this sprint
        @burndown[:points] = {:points => history(:story_points, days), :active => in_sprint}.transpose.collect{|p| p[:active] ? p[:points] : nil}

        # collect hours on this sprint
        @burndown[:hours] = tasks.collect{|t| t.burndown(sprint) }.transpose.collect{|d| d.compact.sum}
        @burndown[:hours] = [nil] * (days.size + 1) if @burndown[:hours].size == 0
        @burndown[:hours] = {:h => @burndown[:hours], :a => in_sprint}.transpose.collect{|h| h[:a] ? h[:h] : nil}

        # points are accepted when the state is accepted
        @burndown[:points_accepted] = {:points => @burndown[:points], :accepted => accepted}.transpose.collect{|p| p[:accepted] ? p[:points] : nil }
        # points are resolved when the state is accepted _or_ the hours are at zero
        @burndown[:points_resolved] = {:points => @burndown[:points], :hours => @burndown[:hours], :accepted => accepted}.transpose.collect{|p| (p[:hours].to_i == 0 || p[:accepted]) ? p[:points] : 0}

        # set hours to zero after the above when the story is not active, would affect resolved when done before this
        @burndown[:hours] = {:hours => @burndown[:hours], :active => active}.transpose.collect{|h| h[:active] ? h[:hours] : 0}

      else
        @burndown = nil
      end
    end

    return @burndown
  end

end
