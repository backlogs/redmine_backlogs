require 'icalendar'

class RbCalendarsController < RbApplicationController
  unloadable

  case Backlogs.platform
    when :redmine
      before_filter :require_admin_or_api_request, :only => :ical
      accept_api_auth :ical
    when :chiliproject
      accept_key_auth :ical
  end

  def ical
    respond_to do |format|
      format.xml { send_data(generate_ical, :disposition => 'attachment') }
    end
  end

  private

  def generate_ical
    cal = Icalendar::Calendar.new

    # current + future sprints
    RbSprint.where("not sprint_start_date is null and not effective_date is null and project_id = ? and effective_date >= ?", @project.id, Date.today).find_each {|sprint|
      summary_text = l(:event_sprint_summary, { :project => @project.name, :summary => sprint.name } )
      description_text = "#{sprint.name}: #{url_for(:controller => 'rb_queries', :only_path => false, :action => 'show', :project_id => @project.id, :sprint_id => sprint.id)}\n#{sprint.description}"

      cal.event do |e|
        e.dtstart     = sprint.sprint_start_date
        e.dtend       = sprint.effective_date
        e.summary     = summary_text
        e.description = description_text
        e.ip_class    = "PRIVATE"
        e.transp      = "TRANSPARENT"
      end
    }

    open_issues = %Q[
        #{IssueStatus.table_name}.is_closed = ?
        and tracker_id in (?)
        and fixed_version_id in (
          select id
          from versions
          where project_id = ?
            and status = 'open'
            and not sprint_start_date is null
            and effective_date >= ?
        )
    ]
    open_issues_and_impediments = %Q[
      (assigned_to_id is null or assigned_to_id = ?)
      and
      (
        (#{open_issues})
        or
        ( #{IssueStatus.table_name}.is_closed = ?
          and #{Issue.table_name}.id in (
            select issue_from_id
            from issue_relations
            join issues on issues.id = issue_to_id and relation_type = 'blocks'
            where #{open_issues})
        )
      )
    ]

    conditions = [open_issues_and_impediments]
    # me or none
    conditions << User.current.id

    # open stories/tasks
    conditions << false
    conditions << RbStory.trackers + [RbTask.tracker]
    conditions << @project.id
    conditions << Date.today

    # open impediments...
    conditions << false

    # ... for open stories/tasks
    conditions << false
    conditions << RbStory.trackers + [RbTask.tracker]
    conditions << @project.id
    conditions << Date.today

    issues = Issue.where(conditions).joins(:status).includes(:status).find_each {|issue|
      summary_text = l(:todo_issue_summary, { :type => issue.tracker.name, :summary => issue.subject } )
      description_text = "#{issue.subject}: #{url_for(:controller => 'issues', :only_path => false, :action => 'show', :id => issue.id)}\n#{issue.description}"
      # I know this should be "cal.todo do", but outlook in it's
      # infinite stupidity doesn't support VTODO
      cal.event do |e|
        e.summary     = summary_text
        e.description = description_text
        e.dtstart     = Date.today
        e.dtend       = (Date.today + 1)
        e.ip_class    = 'PRIVATE'
        e.transp      = 'TRANSPARENT'
      end
    }

    cal.to_ical
  end

end
