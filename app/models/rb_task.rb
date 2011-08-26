require 'date'

class RbTask < Issue
  unloadable

  def self.tracker
    task_tracker = Setting.plugin_redmine_backlogs[:task_tracker]
    return nil if task_tracker.blank?
    return Integer(task_tracker)
  end

  def self.create_with_relationships(params, user_id, project_id, is_impediment = false)
    if Issue.const_defined? "SAFE_ATTRIBUTES"
      attribs = params.clone.delete_if {|k,v| !RbTask::SAFE_ATTRIBUTES.include?(k) && !RbTask.column_names.include?(k) }
    else
      attribs = params.clone.delete_if {|k,v| !Issue.new.safe_attribute_names.include?(k.to_s) && !RbTask.column_names.include?(k)}
    end

    attribs['author_id'] = user_id
    attribs['tracker_id'] = RbTask.tracker
    attribs['project_id'] = project_id

    blocks = params.delete('blocks')

    task = new(attribs)
    task.save!

    raise "Not a valid block list" if is_impediment && !task.validate_blocks_list(blocks)

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
    if Issue.const_defined? "SAFE_ATTRIBUTES"
      attribs = params.clone.delete_if {|k,v| !RbTask::SAFE_ATTRIBUTES.include?(k) }
    else
      attribs = params.clone.delete_if {|k,v| !Issue.new.safe_attribute_names.include?(k.to_s) }
    end

    valid_relationships = if is_impediment && params[:blocks] #if blocks param was not sent, that means the impediment was just dragged
                            validate_blocks_list(params[:blocks])
                          else
                            true
                          end

    if valid_relationships && result = journalized_update_attributes!(attribs)
      move_before params[:next] unless is_impediment # impediments are not hosted under a single parent, so you can't tree-order them
      update_blocked_list params[:blocks].split(/\D+/) if params[:blocks]
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
    unless @burndown
      sprint ||= story.fixed_version.becomes(RbSprint)
      if sprint
        days = sprint.days(:active)
        @burndown = {:hr => history(:estimated_hours, days), :sprint => history(:fixed_version_id, days)}.transpose.collect{|h| h[:sprint] == sprint.id ? h[:hr] : nil}
      else
        @burndown = nil
      end
    end

    return @burndown
  end

  def set_initial_estimate(hours)
    if fixed_version_id and fixed_version.sprint_start_date
      time = [fixed_version.sprint_start_date.to_time, created_on].max
    else
      time = created_on
    end

    jd = JournalDetail.find(:first, :order => "journals.created_on desc", :joins => :journal,
      :conditions => ["property = 'attr' and prop_key = 'estimated_hours' and journalized_type = 'Issue' and journalized_id = ? and created_on <= ?", id, time])

    if jd
      if jd.value.blank? || Float(jd.value) != hours
        hours = hours.to_s.gsub(/\.0+$/, '')

        JournalDetail.connection.execute("update journal_details set value='#{hours}' where id = #{jd.id}")

        jd = JournalDetail.find(:first, :order => "journals.created_on asc", :joins => :journal,
          :conditions => ["property = 'attr' and prop_key = 'estimated_hours' and journalized_type = 'Issue' and journalized_id = ? and created_on >= ?", id, jd.journal.created_on])
        JournalDetail.connection.execute("update journal_details set old_value='#{hours}' where id = #{jd.id}") if jd
      end
    else
      if hours != estimated_hours
        j = Journal.new(:journalized => self, :user => User.current, :created_on => time)
        j.details << JournalDetail.new(:property => 'attr', :prop_key => 'estimated_hours', :value => estimated_hours, :old_value => hours)
        j.save!
      end
    end
  end

  def time_entry_add(params)
    # Will also save time entry if only comment is filled, hours will default to 0. We don't want the user 
    # to loose a precious comment if hours is accidently left blank.
    if !params[:time_entry_hours].blank? || !params[:time_entry_comments].blank?
      @time_entry = TimeEntry.new(:issue => self, :project => self.project) 
      # Make sure user has permission to edit time entries to allow 
      # logging time for other users
      if User.current.allowed_to?(:edit_time_entries, self.project)
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
