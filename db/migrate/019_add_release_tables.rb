class AddReleaseTables < ActiveRecord::Migration
  def self.up
    create_table :releases do |t|
      t.column :name, :string, :null => false
      t.column :release_start_date, :date, :null => false
      t.column :release_end_date, :date, :null => false
      t.column :initial_story_points, :integer, :null => true
      t.column :project_id, :integer, :null => false
      t.timestamps
    end

    create_table :release_burndown_days do |t|
      t.column :release_id, :integer, :null => false
      t.column :day, :date, :null => false
      t.column :remaining_story_points, :integer, :null => false
      t.timestamps
    end
  end

  def self.down
    drop_table :releases
    if ActiveRecord::Base.connection.table_exists?('release_burndown_days')
      drop_table :release_burndown_days
    end
  end
end
