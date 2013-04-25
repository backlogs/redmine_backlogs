class MigrateLegacy < ActiveRecord::Migration
  def self.normalize_value(v, t)
    v = v[1] if v.is_a?(Array)

    return nil if v.class == NilClass

    case t
      when :int
        v = v.to_s
        v.gsub(/\.[0-9]*$/, '')
        return (v.to_s =~ /^[0-9]+$/ ? Integer(v) : nil)

      when :bool
        if [TrueClass, FalseClass].include?(v.class)
          return v
        else
          return ! (['', '0', 'false', 'f'].include?("#{v}"))
        end

      else
        return v
    end
  end

  def self.row(r, t)
    normalized = []
    r.each_with_index{|v, i|
      normalized << MigrateLegacy.normalize_value(v, t[i])
    }
    return normalized
  end

  def self.up
    unless ActiveRecord::Base.connection.table_exists?('rb_issue_history')
      create_table :rb_issue_history do |t|
        t.column :issue_id,    :integer, :default => 0,  :null => false
        t.text   :history
      end
      add_index :rb_issue_history, :issue_id, :unique => true
    end

    unless ActiveRecord::Base.connection.table_exists?('rb_sprint_burndown')
      create_table :rb_sprint_burndown do |t|
        t.column :version_id,    :integer, :default => 0,  :null => false
        t.text   :stories
        t.text   :burndown
        t.timestamps
      end
      add_index :rb_sprint_burndown, :version_id, :unique => true
    end

    #migration 40 wants to add release-issue relation. issue_history tracks this, so the relation needs to be there before a history migration is performed
    unless ActiveRecord::Base.connection.column_exists?(:issues, :release_id)
      add_column :issues, :release_id, :integer
    end

    adapter = ActiveRecord::Base.connection.instance_variable_get("@config")[:adapter].downcase

    ActiveRecord::Base.connection.commit_db_transaction unless adapter.include?('sqlite')

    if ActiveRecord::Base.connection.tables.include?('backlogs')
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
          select projects.id as project_id, pt.tracker_id as tracker_id
          from projects
          left join projects_trackers pt on pt.project_id = projects.id").each { |row|

        project_id, tracker_id = MigrateLegacy.row(row, [:int, :int])

        trackers[project_id] ||= {}
        trackers[project_id][:story] = tracker_id if RbStory.trackers.include?(tracker_id)
        trackers[project_id][:task] = tracker_id if RbTask.tracker == tracker_id
      }

      # close existing transactions and turn on autocommit
      ActiveRecord::Base.connection.commit_db_transaction unless adapter.include?('sqlite')

      say_with_time "Migrating Backlogs data..." do
        bottom = 0
        execute("select coalesce(max(position), 0) from items").each { |row| 
          bottom = row[0].to_i
        }
        bottom += 1

        connection = ActiveRecord::Base.connection

        stories = execute "
          select story.issue_id, story.points, versions.id, issues.project_id
          from items story
          join issues on issues.id = story.issue_id
          left join items parent on parent.id = story.parent_id and story.parent_id <> 0
          left join backlogs sprint on story.backlog_id = sprint.id and sprint.id <> 0
          left join versions on versions.id = sprint.version_id and sprint.version_id <> 0
          where parent.id is null
          order by coalesce(story.position, #{bottom}) asc, story.created_at asc"

        stories.each { |row|
          id, points, sprint, project = MigrateLegacy.row(row, [:int, :int, :int, :int])

          begin
            Project.find(project)
          rescue ActiveRecord::RecordNotFound
            say "Skipping story #{id} on non-existent project #{project}"
            next
          end

          story = nil
          begin
            story = RbStory.find(id)
          rescue ActiveRecord::RecordNotFound
            say "Skipping non-existent story #{id}"
            next
          end
          say "Updating story #{id}"

          if ! RbStory.trackers.include?(story.tracker_id)
            raise "Project #{project} does not have a story tracker configured" unless trackers[project] && trackers[project][:story]
            story.tracker_id = trackers[project][:story]
            story.save!
          end

          story.fixed_version_id = sprint
          story.story_points = points
          story.save!

          story.move_to_bottom
        }

        tasks = execute "
          select task.issue_id, versions.id, parent.issue_id, task_issue.project_id
          from items task
          join issues task_issue on task_issue.id = task.issue_id
          join items parent on parent.id = task.parent_id and task.parent_id <> 0
          join issues parent_issue on parent_issue.id = parent.issue_id
          left join backlogs sprint on task.backlog_id = sprint.id and sprint.id <> 0
          left join versions on versions.id = sprint.version_id and sprint.version_id <> 0
          order by coalesce(task.position, #{bottom}), task.created_at"

        tasks.each { |row|
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
        }

        res = execute "select version_id, start_date, is_closed from backlogs"
        res.each { |row|
          version, start_date, is_closed = MigrateLegacy.row(row, [:int, :string, :bool])

          status = connection.quote(is_closed ? 'closed' : 'open')
          version = connection.quote(version == 0 || version.to_s.strip == '' ? nil : version)
          start_date = connection.quote(start_date.to_s.strip == '' ? nil : start_date)

          execute "update versions set status = #{status}, sprint_start_date = #{start_date} where id = #{version}"
        }
      end

      execute %{
        insert into burndown_days (version_id, points_committed, points_accepted, created_at)
        select version_id, scope, done, backlog_chart_data.created_at
        from backlogs
        join backlog_chart_data on backlogs.id = backlog_id
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
