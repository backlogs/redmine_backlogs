require 'benchmark'

class BurndownFromJournal < ActiveRecord::Migration
  def self.up

    or_trackers = (RbStory.trackers + [RbTask.tracker]).compact.collect{|t| t.to_s}.join(',')
    or_trackers = " or tracker_id in (#{or_trackers})" if or_trackers != ''

    create_table :backlogs_tmp_initial_remaining do |t|
      t.column :tmp_id, :integer, :null => false
      t.column :tmp_initial, :float, :null => false
      t.column :tmp_remaining, :float, :null => false
    end

    execute "insert into backlogs_tmp_initial_remaining (tmp_id, tmp_initial, tmp_remaining)
             select id, estimated_hours, remaining_hours
             from issues
             where (not remaining_hours is null and not estimated_hours is null) #{or_trackers}"

    execute "update issues
             set estimated_hours = (select tmp_remaining from backlogs_tmp_initial_remaining where tmp_id = id)
             where id in (select tmp_id from backlogs_tmp_initial_remaining)"
            
    # set initial estimate to hours cached above
    issues = RbTask.find_by_sql('select * from backlogs_tmp_initial_remaining')
    converted = 0
    if issues.size != 0
      puts "Setting initial value for #{issues.size} issues. This will take a while. Sorry."
      while ((chunk = issues.slice!(1, 100)).size != 0) do
        b = Benchmark.measure {
          chunk.each {|tmp|
            issue = RbTask.find(tmp.tmp_id)
            issue.set_initial_estimate(tmp.tmp_initial) if tmp.tmp_initial && tmp.tmp_initial != 0
          }
        }
        converted += chunk.size
        speed = chunk.size.to_f / b.real
        puts "#{converted} values set, (#{Integer(speed)} issues/second), estimated time remaining: #{Integer(issues.size / speed)}s"
      end
    end

    # remove journal entries for estimated_hours for converted journals (shouldn't have changed much since remaining was kept in a separate column)
    execute "delete from journal_details where prop_key = 'estimated_hours'
             and journal_id in (select id from journals
                                where journalized_type='Issue'
                                and journalized_id in (select tmp_id from backlogs_tmp_initial_remaining))"

    # change journal for remaining_hours into estimated_hours
    execute "update journal_details set prop_key='estimated_hours'
             where prop_key='remaining_hours'
             and journal_id in (select id from journals
                                where journalized_type='Issue'
                                and journalized_id in (select tmp_id from backlogs_tmp_initial_remaining))"

    execute "delete from journal_details where prop_key='remaining_hours'"

    # clean up any journal entries without details
    execute "delete from journals where not id in (select journal_id from journal_details)"

    remove_column :issues, :remaining_hours
    drop_table :burndown_days
    drop_table :backlogs_tmp_initial_remaining

  end

  def self.down
    raise ActiveRecord::IrreversibleMigration
  end
end
