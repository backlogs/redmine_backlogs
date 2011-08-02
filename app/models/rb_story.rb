class RbStory < Issue
    unloadable

    acts_as_list

    def self.find_params(options)
      project_id = options.delete(:project_id)
      sprint_id = options.delete(:sprint_id)
      include_backlog = options.delete(:include_backlog)

      sprint_id = RbSprint.open_sprints(Project.find(project_id)).collect{|s| s.id} if project_id && sprint_id == :open

      project_id = nil if !include_backlog && sprint_id
      sprint_id = [sprint_id] if sprint_id && !sprint_id.is_a?(Array)

      raise "Specify either sprint or project id" unless (sprint_id || project_id)

      options[:joins] = [options[:joins]] unless options[:joins].is_a?(Array)

      conditions = []
      parameters = []

      if project_id
        conditions << "(tracker_id in (?) and fixed_version_id is NULL and #{IssueStatus.table_name}.is_closed = ? and (#{Project.find(project_id).project_condition(true)}))"
        parameters += [RbStory.trackers, false]
        options[:joins] << :project
        options[:joins] << :status
      end

      if sprint_id
        conditions << "(tracker_id in (?) and fixed_version_id in (?))"
        parameters += [RbStory.trackers, sprint_id]
      end

      conditions = conditions.join(' or ')

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
        stories << story
      }

      return stories
    end

    def self.product_backlog(project, limit=nil)
      return RbStory.backlog(:project_id => project.id, :limit => limit)
    end

    def self.sprint_backlog(sprint, options={})
      return RbStory.backlog(options.merge(:sprint_id => sprint.id))
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
      s.move_after(params['prev_id']) if s.save!
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

      begin
        prev = self.class.find(prev_id)
      rescue ActiveRecord::RecordNotFound
        prev = nil
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
    @rank ||= Issue.count(RbStory.find_params(
      :sprint_id => self.fixed_version_id,
      :project_id => self.project.id,
      :conditions => self.position.blank? ? ['(issues.position is NULL and issues.id <= ?) or not issues.position is NULL', self.id] : ['not issues.position is NULL and issues.position <= ?', self.position]
    ))

    return @rank
  end

  def self.at_rank(rank, options)
    return RbStory.find(:first, RbStory.find_params(options.merge(
                      :order => RbStory::ORDER,
                      :limit => 1,
                      :offset => rank - 1)))
  end

  def burndown
    return @burndown if @burndown
    @burndown = {}

    dates = fixed_version.becomes(RbSprint).days(:active).collect{|d| Time.local(d.year, d.mon, d.mday, 0, 0, 0) }
    dates[0] = :first
    dates << :last

    @burndown[:status] = dates.collect{|d| IssueStatus.find(Integer(historic(d, 'status_id'))) }
    @burndown[:points] = dates.collect{|d| historic(d, 'story_points')}.collect{|p| p.nil? ? nil : Integer(p) }

    @burndown[:points_accepted] = (0..dates.size - 1).collect{|i| @burndown[:status][i].backlog == :accepted ? @burndown[:points][i] : 0 }

    taskdata = tasks.collect{|t| t.burndown }
    @burndown[:hours] = (0..dates.size - 1).collect{|i| taskdata.collect{|t| t[:hours][i] }.compact.inject(0) {|total, h| total + h}}

    @burndown[:points_resolved] = (0..dates.size - 1).collect{|i| @burndown[:hours][i] == 0 ? @burndown[:points][i] : 0}

    return @burndown
  end

end
