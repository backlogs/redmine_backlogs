include RbCommonHelper

class RbTaskboardsController < RbApplicationController
  unloadable

  #load the issues historic's status by github.com/ricardobaumann
  def load_stories_status(date,stories)
    @issue_st_hist = Hash.new
    stories.each do |story|
      begin
        journal = Journal.where("journalized_id = ? and created_on <= ?",story.id,date).last
        if journal  

          JournalDetail.where("journal_id = ?",journal.id).each do |detail|
            if (detail.prop_key == 'status_id')
              @issue_st_hist.merge!({story.id => IssueStatus.find(detail.old_value.to_i)})
            end
          end
        end
      rescue => e
        
      end
    end
  end

  def identity_historic_closed_tasks
    query = "
      select jd.value, max(j.created_on) as created_on ,i.id
        from journals j 
          inner join issues parent
            left join versions v
              on parent.fixed_version_id = v.id
              and v.id = ?
            inner join issues i
                inner join issue_statuses status
                  on i.status_id = status.id
              on parent.id = i.parent_id  
            on j.journalized_id = parent.id
          inner join journal_details jd
            on j.id = jd.journal_id
      where status.is_closed
        and j.journalized_type = 'Issue'
        and jd.prop_key = 'fixed_version_id'
        and cast(jd.value as integer) <> v.id
      group by jd.value, parent.id, i.id
    "
    
    ActiveRecord::Base.connection.select_all(
      ActiveRecord::Base.send(:sanitize_sql_array, 
       [query, @sprint.id])
    ).map { |record| record["id"].to_i }

  end

  def show
    stories = @sprint.stories
    
    p = params['default_task_from'] 
    if (p)  
      parent = stories.select{ |s| s.id == p.to_i}.first
      puts "\n\n\nestoria pai: #{parent.subject}"
      if (parent)
        
          task = Issue.new
          task.parent_issue_id = parent.id
          task.subject = parent.subject
          task.description = parent.description
          task.priority = IssuePriority.default
          task.tracker = parent.tracker
          task.author = parent.author
          task.project = parent.project
          puts "save: #{task.subject}"  
          task.save
          #validates_presence_of :subject, :priority, :project, :tracker, :author, :status
          puts "\n\n\npassou save #{task.id} #{task.persisted?}"
      end
    end
    
    

    @story_ids    = stories.map{|s| s.id}
    #@closed_tasks = identity_historic_closed_tasks
    puts "\n\n\ntestando: "+@closed_tasks.to_s
    @settings = Backlogs.settings

    ## determine status columns to show
    tracker = Tracker.find_by_id(RbTask.tracker)
    statuses = tracker.issue_statuses
    # disable columns by default
    if User.current.admin?
      @statuses = statuses
    else
      enabled = {}
      statuses.each{|s| enabled[s.id] = false}
      # enable all statuses held by current tasks, regardless of whether the current user has access
      RbTask.find(:all, :conditions => ['fixed_version_id = ?', @sprint.id]).each {|task| enabled[task.status_id] = true }

      roles = User.current.roles_for_project(@project)
      #@transitions = {}
      statuses.each {|status|

        # enable all statuses the current user can reach from any task status
        [false, true].each {|creator|
          [false, true].each {|assignee|

            allowed = status.new_statuses_allowed_to(roles, tracker, creator, assignee).collect{|s| s.id}
            #@transitions["c#{creator ? 'y' : 'n'}a#{assignee ? 'y' : 'n'}"] = allowed
            allowed.each{|s| enabled[s] = true}
          }
        }
      }
      @statuses = statuses.select{|s| enabled[s.id]}
    end

    if @sprint.stories.size == 0
      @last_updated = nil
    else
      @last_updated = RbTask.find(:first,
                        :conditions => ['tracker_id = ? and fixed_version_id = ?', RbTask.tracker, @sprint.stories[0].fixed_version_id],
                        :order      => "updated_on DESC")
    end

    if params['created_on']
      load_stories_status(DateTime.strptime(params['created_on'],'%s'),stories)
    end

    respond_to do |format|
      format.html { render action: "show", :layout => "rb" }
    end
  end

  def current
    sprint = @project.active_sprint
    if sprint
      redirect_to :controller => 'rb_taskboards', :action => 'show', :sprint_id => sprint
      return
    end
    respond_to do |format|
      format.html { redirect_back_or_default(project_url(@project)) }
    end
  end

end
