class DropReleaseBurndownDays < ActiveRecord::Migration
  def self.up
    if ActiveRecord::Base.connection.table_exists?('release_burndown_days')
      drop_table :release_burndown_days
    end
    remove_column :releases, :initial_story_points
  end

  def self.down
    create_table :release_burndown_days do |t|
      t.column :release_id, :integer, :null => false
      t.column :day, :date, :null => false
      t.column :remaining_story_points, :integer, :null => false
      t.timestamps
    end
    add_column :releases, :initial_story_points, :integer, :null => true
  end
end

