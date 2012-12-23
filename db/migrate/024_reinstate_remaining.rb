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
    return e.sum
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

    catch (:done) do
      throw :done if Issue.column_names.include?('remaining_hours')

      add_column :issues, :remaining_hours, :float            

      execute "update issues set created_on = updated_on where created_on is NULL"

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
          sql << "update journal_details set prop_key='remaining_hours'
                   where prop_key='estimated_hours'
                   and journal_id in (select id from journals
                                  where journalized_type='Issue'
                                  and journalized_id in (#{ids}))"

        }
        converted += chunk.size
        speed = chunk.size.to_f / b.real
        puts "#{converted} values set, (#{Integer(speed)} issues/second), estimated time remaining: #{Integer(((issues.size - converted) + 1) / speed)}s"
      end

      sql.each{|stmt| execute(stmt) }

      # clean up any journal entries without details
      execute "delete from journals where not id in (select journal_id from journal_details) and (notes is NULL or notes = '')"

      # stupid mysql doesn't support self-referential subselect updates
      create_table :backlogs_tmp_estimated_hours do |t|
        t.column :id, :integer, :null => false
        t.column :estimated_hours, :float, :null => false
        t.column :remaining_hours, :float, :null => false
      end

      # sum up all leaf issues
      execute "insert into backlogs_tmp_estimated_hours (id, estimated_hours, remaining_hours)
               select story.id, coalesce(sum(tasks.estimated_hours), 0), coalesce(sum(tasks.remaining_hours), 0)
               from issues story
               join issues tasks on tasks.root_id = story.root_id and tasks.lft > story.lft and tasks.rgt < story.rgt and tasks.lft = tasks.rgt - 1
               group by story.id"

      # only update non-leaf issues
      execute "update issues
               set
                 estimated_hours = (select estimated_hours from backlogs_tmp_estimated_hours where backlogs_tmp_estimated_hours.id = issues.id),
                 remaining_hours = (select remaining_hours from backlogs_tmp_estimated_hours where backlogs_tmp_estimated_hours.id = issues.id)
               where id in (select id from backlogs_tmp_estimated_hours)"

      drop_table :backlogs_tmp_estimated_hours
    end
  end

  def self.down
    puts "Reverting irreversible migration"
  end
end
