require 'icalendar'

class RbCalendarsController < RbApplicationController
  unloadable

  case Backlogs.platform
  when :redmine
    accept_api_auth :ical
  when :chiliproject
    accept_key_auth :ical
  end

  def ical
    respond_to do |format|
      format.api { send_data(generate_ical, :disposition => 'attachment') }
    end
  end

  private

  def generate_ical
    cal = Icalendar::Calendar.new

    # current + future sprints
    RbSprint.find(:all, :conditions => ["NOT sprint_start_date IS NULL AND NOT effective_date IS NULL AND project_id = ? AND effective_date >= ?", @project.id, Date.today]).each do |sprint|
      summary_text = l(:event_sprint_summary, { :project => @project.name, :summary => sprint.name } )
      description_text = "#{sprint.name}: #{url_for(:controller => 'rb_queries', :only_path => false, :action => 'show', :project_id => @project.id, :sprint_id => sprint.id)}\n#{sprint.description}"

      cal.event do
        dtstart     sprint.sprint_start_date
        dtend       sprint.effective_date
        summary     summary_text
        description description_text
        klass       'PRIVATE'
        transp      'TRANSPARENT'
      end
    end

    open_issues = %Q[
        #{IssueStatus.table_name}.is_closed = ?
        AND tracker_id IN (?)
        AND fixed_version_id IN (
          SELECT id
          FROM versions
          WHERE project_id = ?
            AND status = 'open'
            AND NOT sprint_start_date IS NULL
            AND effective_date >= ?
        )
    ]
    open_issues_and_impediments = %Q[
      (assigned_to_id IS NULL OR assigned_to_id = ?)
      AND
      (
        (#{open_issues})
        OR
        ( #{IssueStatus.table_name}.is_closed = ?
          AND #{Issue.table_name}.id IN (
            SELECT issue_from_id
            FROM issue_relations
            JOIN issues ON issues.id = issue_to_id AND relation_type = 'blocks'
            WHERE #{open_issues})
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

    issues = Issue.find(:all, :include => :status, :conditions => conditions).each do |issue|
      summary_text = l(:todo_issue_summary, { :type => issue.tracker.name, :summary => issue.subject })
      description_text = "#{issue.subject}: #{url_for(:controller => 'issues', :only_path => false, :action => 'show', :id => issue.id)}\n#{issue.description}"
      # I know this should be "cal.todo do", but outlook in it's
      # infinite stupidity doesn't support VTODO
      cal.event do
        summary     summary_text
        description description_text
        dtstart     Date.today
        dtend       (Date.today + 1)
        klass       'PRIVATE'
        transp      'TRANSPARENT'
      end
    end

    cal.to_ical
  end
end
