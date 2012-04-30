class MigrateLegacy < ActiveRecord::Migration
  def self.normalize_value(v, t)
    return nil if v.class == NilClass

    case t
    when :int
      return Integer(v)
    when :bool
      if [TrueClass, FalseClass].include?(v.class)
        return v
      else
        return ! (['', '0'].include?("#{v}"))
      end
    else
      return v
    end
  end

  def self.row(r, t)
    normalized = []
    r.each_with_index do |v, i|
      normalized << MigrateLegacy.normalize_value(v, t[i])
    end
    normalized
  end

  def self.up
    begin
      execute "SELECT COUNT(*) FROM backlogs"
      legacy = true
    rescue
      legacy = false
    end

    adapter = ActiveRecord::Base.connection.instance_variable_get("@config")[:adapter].downcase

    ActiveRecord::Base.connection.commit_db_transaction unless adapter.include?('sqlite')

    if legacy
      RbStory.reset_column_information
      Issue.reset_column_information
      RbTask.reset_column_information

      if RbStory.trackers.size == 0 || RbTask.tracker.nil?
        raise "Please configure the Backlogs Story and Task trackers before migrating.

        You do this by starting Redmine and going to \"Administration -> Plugins -> Redmine Scrum Plugin -> Configure\"
        and setting up the Task tracker and one or more Story trackers.
        You might have to go to  \"Administration -> Trackers\" first
        and create new trackers for this purpose. After doing this, stop
        redmine and re-run this migration."
      end

      trackers = {}

      # find story/task trackers per project
      execute("
          SELECT projects.id AS project_id, pt.tracker_id AS tracker_id
          FROM projects
          LEFT JOIN projects_trackers pt ON pt.project_id = projects.id").each do |row|

        project_id, tracker_id = MigrateLegacy.row(row, [:int, :int])

        trackers[project_id] ||= {}
        trackers[project_id][:story] = tracker_id if RbStory.trackers.include?(tracker_id)
        trackers[project_id][:task] = tracker_id if RbTask.tracker == tracker_id
      end

      # close existing transactions and turn on autocommit
      ActiveRecord::Base.connection.commit_db_transaction unless adapter.include?('sqlite')

      say_with_time "Migrating Backlogs data..." do
        bottom = 0
        execute("SELECT COALESCE(MAX(position), 0) FROM items").each do |row|
          bottom = row[0].to_i
        end
        bottom += 1

        connection = ActiveRecord::Base.connection

        stories = execute "
          SELECT story.issue_id, story.points, versions.id, issues.project_id
          FROM items story
          JOIN issues ON issues.id = story.issue_id
          LEFT JOIN items parent ON parent.id = story.parent_id AND story.parent_id <> 0
          LEFT JOIN backlogs sprint ON story.backlog_id = sprint.id AND sprint.id <> 0
          LEFT JOIN versions ON versions.id = sprint.version_id AND sprint.version_id <> 0
          WHERE parent.id IS NULL
          ORDER BY COALESCE(story.position, #{bottom}) DESC, story.created_at DESC"

        stories.each do |row|
          id, points, sprint, project = MigrateLegacy.row(row, [:int, :int, :int, :int])

          say "Updating story #{id}"
          story = RbStory.find(id)

          if ! RbStory.trackers.include?(story.tracker_id)
            raise "Project #{project} does not have a story tracker configured" unless trackers[project][:story]
            story.tracker_id = trackers[project][:story]
            story.save!
          end

          story.fixed_version_id = sprint
          story.story_points = points
          story.save!

          # because we're inserting the stories last-first, this
          # position gets shifted down 1 spot each time, yielding a
          # neatly compacted position list
          story.insert_at 1
        end

        tasks = execute "
          SELECT task.issue_id, versions.id, parent.issue_id, task_issue.project_id
          FROM items task
          JOIN issues task_issue ON task_issue.id = task.issue_id
          JOIN items parent ON parent.id = task.parent_id AND task.parent_id <> 0
          JOIN issues parent_issue ON parent_issue.id = parent.issue_id
          LEFT JOIN backlogs sprint ON task.backlog_id = sprint.id AND sprint.id <> 0
          LEFT JOIN versions ON versions.id = sprint.version_id AND sprint.version_id <> 0
          ORDER BY COALESCE(task.position, #{bottom}), task.created_at"

        tasks.each do |row|
          id, sprint, parent_id, project = MigrateLegacy.row(row, [:int, :int, :int, :int])

          say "Updating task #{id}"

          task = RbTask.find(id)

          if ! RbTask.tracker == task.tracker_id
            raise "Project #{project} does not have a task tracker configured" unless trackers[project][:task]
            task.tracker_id = trackers[project][:task]
            task.save!
          end

          # because we're inserting the tasks first-last, adding it to
          # the story will yield the correct order
          task.fixed_version_id = sprint
          task.parent_issue_id = parent_id
          task.save!
        end

        res = execute "SELECT version_id, start_date, is_closed FROM backlogs"
        res.each do |row|
          version, start_date, is_closed = MigrateLegacy.row(row, [:int, :string, :bool])

          status = connection.quote(is_closed ? 'closed' : 'open')
          version = connection.quote(version == 0 ? nil : version)
          start_date = connection.quote(start_date)

          execute "UPDATE versions SET status = #{status}, sprint_start_date = #{start_date} WHERE id = #{version}"
        end
      end

      execute %{
        INSERT INTO burndown_days (version_id, points_committed, points_accepted, created_at)
        SELECT version_id, scope, done, backlog_chart_data.created_at
        FROM backlogs
        JOIN backlog_chart_data ON backlogs.id = backlog_id
        }
      ActiveRecord::Base.connection.commit_db_transaction unless adapter.include?('sqlite')

      drop_table :backlogs
      drop_table :items
    end
  end

  def self.down
    #pass
  end
end
