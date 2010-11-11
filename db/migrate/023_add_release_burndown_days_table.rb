class AddReleaseBurndownDaysTable < ActiveRecord::Migration
  def self.up
    create_table :release_burndown_days do |t|
      t.column :release_id, :integer, :null => false
      t.column :day, :date, :null => false
      t.column :remaining_story_points, :integer, :null => false
      t.timestamps
    end
  end

  def self.down
    drop_table :release_burndown_days
  end
end
