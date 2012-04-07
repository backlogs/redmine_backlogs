require 'date'

class RbTask < Issue
  unloadable

  def self.tracker
    task_tracker = Backlogs.setting[:task_tracker]
    return nil if task_tracker.blank?
    return Integer(task_tracker)
  end

  def self.rb_safe_attributes(params)
    if Issue.const_defined? "SAFE_ATTRIBUTES"
      safe_attributes_names = RbTask::SAFE_ATTRIBUTES
    else
      safe_attributes_names = Issue.new(
        :project_id=>params[:project_id] # required to verify "safeness"
      ).safe_attribute_names
    end
    attribs = params.select {|k,v| safe_attributes_names.include?(k) }
    attribs = Hash[*attribs.flatten] if attribs.is_a?(Array)
    return attribs
  end

  def self.create_with_relationships(params, user_id, project_id, is_impediment = false)

    attribs = rb_safe_attributes(params)

    attribs['author_id'] = user_id
    attribs['tracker_id'] = RbTask.tracker
    attribs['project_id'] = project_id

    blocks = params.delete('blocks')

    task = new(attribs)
    if params['parent_issue_id']
      parent = Issue.find(params['parent_issue_id'])
      task.start_date = parent.start_date
    end
    task.save!

    raise "Block list must be comma-separated list of task IDs" if is_impediment && !task.validate_blocks_list(blocks)

    task.move_before params[:next] unless is_impediment # impediments are not hosted under a single parent, so you can't tree-order them
    task.update_blocked_list blocks.split(/\D+/) if is_impediment
    task.time_entry_add(params)

    return task
  end

  # TODO: there's an assumption here that impediments always have the
  # task-tracker as their tracker, and are top-level issues.
  def self.find_all_updated_since(since, project_id, find_impediments = false)
    find(:all,
         :conditions => ["project_id = ? AND updated_on > ? AND tracker_id in (?) and parent_id IS #{ find_impediments ? '' : 'NOT' } NULL", project_id, Time.parse(since), tracker],
         :order => "updated_on ASC")
  end

  def self.tasks_for(story_id)
    tasks = []
    story = RbStory.find_by_id(story_id)
    if RbStory.trackers.include?(story.tracker_id)
      story.descendants.each_with_index {|task, i|
        task = task.becomes(RbTask)
        task.rank = i + 1
        tasks << task 
      }
    end
    return tasks
  end

  def update_with_relationships(params, is_impediment = false)
    time_entry_add(params)

    attribs = RbTask.rb_safe_attributes(params)

    # Auto assign task to current user when
    # 1. the task is not assigned to anyone yet
    # 2. task status changed (i.e. Updating task name or remaining hours won't assign task to user)
    # Can be enabled/disabled in setting page
    if Backlogs.setting[:auto_assign_task] && self.assigned_to_id.blank? && (self.status_id != params[:status_id].to_i)
      attribs[:assigned_to_id] = User.current.id
    end

    valid_relationships = if is_impediment && params[:blocks] #if blocks param was not sent, that means the impediment was just dragged
                            validate_blocks_list(params[:blocks])
                          else
                            true
                          end

    if valid_relationships && result = self.becomes(Issue).journalized_update_attributes!(attribs)
      move_before params[:next] unless is_impediment # impediments are not hosted under a single parent, so you can't tree-order them
      update_blocked_list params[:blocks].split(/\D+/) if params[:blocks]

      if params.has_key?(:remaining_hours)
        begin
          self.remaining_hours = Float(params[:remaining_hours].to_s.gsub(',', '.'))
        rescue ArgumentError, TypeError
          RAILS_DEFAULT_LOGGER.warn "#{params[:remaining_hours]} is wrong format for remaining hours."
        end
        sprint_start = self.story.fixed_version.becomes(RbSprint).sprint_start_date if self.story
        self.estimated_hours = self.remaining_hours if (sprint_start == nil) || (Date.today < sprint_start)
        save
      end
                                    
      result
    else
      false
    end
  end

  def update_blocked_list(for_blocking)
    # Existing relationships not in for_blocking should be removed from the 'blocks' list
    relations_from.find(:all, :conditions => "relation_type='blocks'").each{ |ir|
      ir.destroy unless for_blocking.include?( ir[:issue_to_id] )
    }

    already_blocking = relations_from.find(:all, :conditions => "relation_type='blocks'").map{|ir| ir.issue_to_id}

    # Non-existing relationships that are in for_blocking should be added to the 'blocks' list
    for_blocking.select{ |id| !already_blocking.include?(id) }.each{ |id|
      ir = relations_from.new(:relation_type=>'blocks')
      ir[:issue_to_id] = id
      ir.save!
    }
    reload
  end

  def validate_blocks_list(list)
    if list.split(/\D+/).length==0
      errors.add :blocks, :must_have_comma_delimited_list
      false
    else
      true
    end
  end

  # assumes the task is already under the same story as 'id'
  def move_before(id)
    id = nil if id.respond_to?('blank?') && id.blank?
    if id.nil?
      sib = self.siblings
      move_to_right_of sib[-1].id if sib.any?
    else
      move_to_left_of id
    end
  end

  def rank=(r)
    @rank = r
  end

  def rank
    s = self.story
    return nil if !s

    @rank ||= Issue.count( :conditions => ['tracker_id = ? and root_id = ? and lft > ? and lft <= ?', RbTask.tracker, s.root_id, s.lft, self.lft])
    return @rank
  end

  def burndown(sprint = nil)
    return nil unless self.is_task?
    sprint ||= self.fixed_version.becomes(RbSprint) if self.fixed_version
    return nil if sprint.nil? || !sprint.has_burndown?

    return Rails.cache.fetch("RbIssue(#{self.id}@#{self.updated_on}).burndown(#{sprint.id}@#{sprint.updated_on}-#{[Date.today, sprint.effective_date].min})") {
      days = sprint.days(:active)
      series = Backlogs::MergedArray.new
      series.merge(:hours => history(:remaining_hours, days))
      series.merge(:sprint => history(:fixed_version_id, days))
      series.merge(:sprint_start => days.collect{|d| (d == sprint.sprint_start_date)} + [false])
      series.each{|d|
        if d.sprint != sprint.id
          d.hours = nil
        elsif d.sprint_start
          d.hours = self.estimated_hours # self.value_at(:estimated_hours, self.sprint_start_date)
        end
      }
      series.series(:hours)
    }
  end

  def time_entry_add(params)
    # Will also save time entry if only comment is filled, hours will default to 0. We don't want the user 
    # to loose a precious comment if hours is accidently left blank.
    if !params[:time_entry_hours].blank? || !params[:time_entry_comments].blank?
      @time_entry = TimeEntry.new(:issue => self, :project => self.project) 
      # Make sure user has permission to edit time entries to allow 
      # logging time for other users. Use current user in case none is selected
      if User.current.allowed_to?(:edit_time_entries, self.project) && params[:time_entry_user_id].to_i != 0
        @time_entry.user_id = params[:time_entry_user_id]
      else
        # Otherwise log time for current user
        @time_entry.user_id = User.current.id
      end
      if !params[:time_entry_spent_on].blank?
        @time_entry.spent_on = params[:time_entry_spent_on]
      else
        @time_entry.spent_on = Date.today
      end
      @time_entry.hours = params[:time_entry_hours].gsub(',', '.').to_f
      # Choose default activity
      # If default is not defined first activity will be chosen
      if default_activity = TimeEntryActivity.default
        @time_entry.activity_id = default_activity.id
      else
        @time_entry.activity_id = TimeEntryActivity.first.id
      end
      @time_entry.comments = params[:time_entry_comments]
      self.time_entries << @time_entry
    end
  end
end
