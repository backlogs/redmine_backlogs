require 'benchmark'

class BurndownFromJournal < ActiveRecord::Migration
  def self.up
    # estimated_hours final value set to remaining hours, cache estimated_hours (=initial estimate) in remaining hours for later use
    execute "update issues set estimated_hours=remaining_hours, remaining_hours=estimated_hours"

    # set initial estimate to hours cached above
    RbTask.all.each {|issue|
      issue.set_initial_estimate(issue.remaining_hours) if issue.remaining_hours && issue.remaining_hours != 0
    }

    # remove journal entries for remaining_hours
    execute "delete from journal_details where prop_key = 'estimated_hours'"

    # change journal for remaining_hours into estimated_hours
    execute "update journal_details set prop_key='estimated_hours' where prop_key='remaining_hours'"

    # clean up any journal entries without details
    execute "delete from journals where not id in (select journal_id from journal_details)"

    remove_column :issues, :remaining_hours
    drop_table :burndown_days
  end

  def self.down
    raise ActiveRecord::IrreversibleMigration
  end
end
