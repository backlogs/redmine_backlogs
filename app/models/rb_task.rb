require 'date'

class RbTask < Issue
  unloadable

  def self.tracker
    task_tracker = Backlogs.setting[:task_tracker]
    return nil if task_tracker.blank?
    return Integer(task_tracker)
  end

  # unify api between story and task. FIXME: remove this when merging to tracker-free-tasks
  # required for RbServerVariablesHelper.workflow_transitions
  def self.trackers
    [self.tracker]
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
    # lft and rgt fields are handled by acts_as_nested_set
    attribs = attribs.select{|k,v| k != 'lft' and k != 'rgt' }
    attribs = Hash[*attribs.flatten] if attribs.is_a?(Array)
    return attribs
  end

  def self.create_with_relationships(params, user_id, project_id, is_impediment = false)
    attribs = rb_safe_attributes(params)

    attribs['author_id'] = user_id
    attribs['tracker_id'] = RbTask.tracker
    attribs['project_id'] = project_id

    blocks = params.delete('blocks')

#if we are an impediment and have blocks, set our project_id.
#if we have multiple blocked tasks, cross-project relations must be enabled, otherwise save-validation will fail. TODO: make this more user friendly by pre-validating here and suggesting to enable cross-project relation support in redmine base setup.
    if is_impediment and blocks and blocks.strip != ''
      begin
        first_blocked_id = blocks.split(/\D+/)[0].to_i
        attribs['project_id'] = Issue.find_by_id(first_blocked_id).project_id if first_blocked_id
      rescue
      end
    end

    task = new(attribs)
    if params['parent_issue_id']
      parent = Issue.find(params['parent_issue_id'])
      task.start_date = parent.start_date
    end
    task.save!

    raise "Block list must be comma-separated list of task IDs" if is_impediment && !task.validate_blocks_list(blocks) # could we do that before save and integrate cross-project checks?

    task.move_before params[:next] unless is_impediment # impediments are not hosted under a single parent, so you can't tree-order them
    task.update_blocked_list blocks.split(/\D+/) if is_impediment
    task.time_entry_add(params)

    return task
  end

  # TODO: there's an assumption here that impediments always have the
  # task-tracker as their tracker, and are top-level issues.
  def self.find_all_updated_since(since, project_id, find_impediments = false, sprint_id = nil)
    #find all updated visible on taskboard - which may span projects.
    if sprint_id.nil?
      find(:all,
           :conditions => ["project_id = ? AND updated_on > ? AND tracker_id in (?) and parent_id IS #{ find_impediments ? '' : 'NOT' } NULL", project_id, Time.parse(since), tracker],
           :order => "updated_on ASC")
    else
      find(:all,
           :conditions => ["fixed_version_id = ? AND updated_on > ? AND tracker_id in (?) and parent_id IS #{ find_impediments ? '' : 'NOT' } NULL", sprint_id, Time.parse(since), tracker],
           :order => "updated_on ASC")
    end
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

    if valid_relationships && result = self.journalized_update_attributes!(attribs)
      move_before params[:next] unless is_impediment # impediments are not hosted under a single parent, so you can't tree-order them
      update_blocked_list params[:blocks].split(/\D+/) if params[:blocks]

      if params.has_key?(:remaining_hours)
        begin
          self.remaining_hours = Float(params[:remaining_hours].to_s.gsub(',', '.'))
        rescue ArgumentError, TypeError
          Rails.logger.warn "#{params[:remaining_hours]} is wrong format for remaining hours."
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

  def burndown(sprint = nil, status=nil)
    sprint ||= self.fixed_version.becomes(RbSprint) if self.fixed_version
    return nil if sprint.nil? || !sprint.has_burndown?

    self.history.filter(sprint, status).collect{|d|
      if d.nil? || d[:sprint] != sprint.id || d[:tracker] != :task
        nil
      elsif ! d[:status_open]
        0
      else
        d[:hours]
      end
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
