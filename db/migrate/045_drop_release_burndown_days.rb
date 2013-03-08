class DropReleaseBurndownDays < ActiveRecord::Migration
  def self.up
    if ActiveRecord::Base.connection.table_exists?('release_burndown_days')
      drop_table :release_burndown_days
    end
    remove_column :releases, :initial_story_points

    add_index :issues, :release_id
    add_index :issues, :release_relationship
    add_index :releases, :project_id
    add_index :releases, :status
    add_index :releases, :release_start_date
    add_index :releases, :release_end_date
  end

  def self.down
    remove_index :issues, :column => :release_id
    remove_index :issues, :column => :release_relationship
    remove_index :releases, :column => :project_id
    remove_index :releases, :column => :status
    remove_index :releases, :column => :release_start_date
    remove_index :releases, :column => :release_end_date

    create_table :release_burndown_days do |t|
      t.column :release_id, :integer, :null => false
      t.column :day, :date, :null => false
      t.column :remaining_story_points, :integer, :null => false
      t.timestamps
    end
    add_column :releases, :initial_story_points, :integer, :null => true
  end
end

