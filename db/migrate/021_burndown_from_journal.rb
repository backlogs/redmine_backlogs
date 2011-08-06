require 'benchmark'

class BurndownFromJournal < ActiveRecord::Migration
  def self.up

    projects = Project.all.select{|p| p.module_enabled?('backlogs')}.collect{|p| p.id }
    trackers = (RbStory.trackers + [RbTask.tracker]).compact

    if trackers.size > 0
      ids = []
      issues = RbTask.find(:all, :conditions => ['project_id in (?) and tracker_id in (?)', projects, trackers])
      converted = 0
      if issues.size != 0
        puts "Setting initial value for #{issues.size} issues. This will take a while. Sorry."
        issues.in_groups_of(100, false) do |chunk|
          b = Benchmark.measure {
            chunk.each {|issue|
              issue = RbTask.find(issue.id)
              ids << issue.id.to_s
              initial = issue.estimated_hours
              issue.estimated_hours = issue.remaining_hours
              issue.save!
              issue.set_initial_estimate(initial) if initial && initial != 0
            }
          }
          converted += chunk.size
          speed = chunk.size.to_f / b.real
          puts "#{converted} values set, (#{Integer(speed)} issues/second), estimated time remaining: #{Integer(issues.size / speed)}s"
        end
      end

      issues = ids
      if issues.size != 0
        ids.in_groups_of(50, false) do |ids|
          ids = ids.join(',')
          # remove journal entries for estimated_hours for converted journals (shouldn't have changed much since remaining was kept in a separate column)
          execute "delete from journal_details where prop_key = 'estimated_hours'
                  and journal_id in (select id from journals
                                      where journalized_type='Issue'
                                      and journalized_id in (#{ids}))"

          # change journal for remaining_hours into estimated_hours
          execute "update journal_details set prop_key='estimated_hours'
                  where prop_key='remaining_hours'
                  and journal_id in (select id from journals
                                  where journalized_type='Issue'
                                  and journalized_id in (#{ids}))"
        end
      end
    end

    # they're going to go away anyhow
    execute "delete from journal_details where prop_key='remaining_hours'"

    # clean up any journal entries without details
    execute "delete from journals where not id in (select journal_id from journal_details)"
    remove_column :issues, :remaining_hours
    drop_table :burndown_days

    # stupid mysql doesn't support self-referential subselect updates
    create_table :backlogs_tmp_estimated_hours do |t|
      t.column :id, :integer, :null => false
      t.column :estimated_hours, :float, :null => false
    end

    # sum up all leaf issues
    execute "insert into backlogs_tmp_estimated_hours (id, estimated_hours)
             select story.id, sum(tasks.estimated_hours)
             from issues story
             join issues tasks on tasks.root_id = story.root_id and tasks.lft > story.lft and tasks.rgt < story.rgt and tasks.lft = tasks.rgt - 1
             group by story.id"

    # only update non-leaf issues
    execute "update issues
             set estimated_hours = (select estimated_hours from backlogs_tmp_estimated_hours where backlogs_tmp_estimated_hours.id = issues.id)
             where id in (select id from backlogs_tmp_estimated_hours)"

    drop_table :backlogs_tmp_estimated_hours
  end

  def self.down
    raise ActiveRecord::IrreversibleMigration
  end
end
