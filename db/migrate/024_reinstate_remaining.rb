require 'benchmark'

class ReinstateRemaining < ActiveRecord::Migration

  def self.initial_estimate(issue)
    if issue.leaf?
      if issue.fixed_version_id && issue.fixed_version.sprint_start_date
        time = [issue.fixed_version.sprint_start_date.to_time, issue.created_on].compact.max
      else
        time = issue.created_on
      end
      return issue.value_at(:estimated_hours, time)
    end

    e = issue.leaves.collect{|t| ReinstateRemaining.initial_estimate(t)}.compact
    return nil if e.size == 0
    e.sum
  end

  def self.up
    catch (:done) do
      throw :done if Issue.column_names.include?('remaining_hours')

      add_column :issues, :remaining_hours, :float

      execute "UPDATE issues SET created_on = updated_on WHERE created_on IS NULL"

      projects = Project.all.select{|p| Backlogs.configured?(p)}.collect{|p| p.id }
      trackers = (RbStory.trackers + [RbTask.tracker]).compact

      throw :done if trackers.size == 0 || projects.size == 0

      issues = RbTask.find(:all, :conditions => ['project_id in (?) and tracker_id in (?)', projects, trackers]).to_a
      converted = 0

      puts "Reverting estimated hours for #{issues.size} issues. This will take a while. Sorry."
      sql = []
      issues.in_groups_of(200, false) do |chunk|
        b = Benchmark.measure {
          chunk.each {|task|
            task.reload
            task.remaining_hours = task.estimated_hours
            task.estimated_hours = initial_estimate(task)
            task.save!
          }

          ids = chunk.collect{|i| i.id.to_s}.join(',')

          # change journal for remaining_hours into estimated_hours
          sql << "UPDATE journal_details SET prop_key = 'remaining_hours'
                  WHERE prop_key = 'estimated_hours'
                  AND journal_id IN (SELECT id FROM journals
                                     WHERE journalized_type = 'Issue'
                                     AND journalized_id IN (#{ids}))"

        }
        converted += chunk.size
        speed = chunk.size.to_f / b.real
        puts "#{converted} values set, (#{Integer(speed)} issues/second), estimated time remaining: #{Integer(((issues.size - converted) + 1) / speed)}s"
      end

      sql.each{|stmt| execute(stmt) }

      # clean up any journal entries without details
      execute "DELETE FROM journals WHERE NOT id IN (SELECT journal_id FROM journal_details) AND (notes IS NULL OR notes = '')"

      # stupid mysql doesn't support self-referential subselect updates
      create_table :backlogs_tmp_estimated_hours do |t|
        t.column :id, :integer, :null => false
        t.column :estimated_hours, :float, :null => false
        t.column :remaining_hours, :float, :null => false
      end

      # sum up all leaf issues
      execute "INSERT INTO backlogs_tmp_estimated_hours (id, estimated_hours, remaining_hours)
               SELECT story.id, COALESCE(SUM(tasks.estimated_hours), 0), COALESCE(SUM(tasks.remaining_hours), 0)
               FROM issues story
               JOIN issues tasks ON tasks.root_id = story.root_id AND tasks.lft > story.lft AND tasks.rgt < story.rgt AND tasks.lft = tasks.rgt - 1
               GROUP BY story.id"

      # only update non-leaf issues
      execute "UPDATE issues
               SET
                 estimated_hours = (SELECT estimated_hours FROM backlogs_tmp_estimated_hours WHERE backlogs_tmp_estimated_hours.id = issues.id),
                 remaining_hours = (SELECT remaining_hours FROM backlogs_tmp_estimated_hours WHERE backlogs_tmp_estimated_hours.id = issues.id)
               WHERE id IN (SELECT id FROM backlogs_tmp_estimated_hours)"

      drop_table :backlogs_tmp_estimated_hours
    end
  end

  def self.down
    raise ActiveRecord::IrreversibleMigration
  end
end
