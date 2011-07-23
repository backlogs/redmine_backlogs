class BurndownFromJournal < ActiveRecord::Migration
  def self.up
    execute "update journal_details set prop_key = 'estimated_hours' where prop_key = 'remaining_hours' and not old_value is null"
    execute "delete from journal_details where prop_key = 'remaining_hours'"
    execute "update issues set estimated_hours = remaining_hours where not remaining_hours is null"
    remove_column :issues, :remaining_hours
    drop_table :burndown_days
  end

  def self.down
    raise ActiveRecord::IrreversibleMigration
  end
end
