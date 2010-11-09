class MoveReleaseToOwnTable < ActiveRecord::Migration
  def self.up
    drop_table :releases
    create_table :releases do |t|
      t.column :release_start_date, :date, :null => true
      t.column :release_end_date, :date, :null => true
      t.column :initial_story_points, :integer, :null => true
      t.column :project_id, :integer, :null => false
      t.timestamps
    end

    remove_column :projects, :release_start_date
    remove_column :projects, :release_end_date
    remove_column :projects, :initial_story_points
  end

  def self.down
    drop_table :releases

    add_column :projects, :release_start_date, :date, :null => true
    add_column :projects, :release_end_date, :date, :null => true
    add_column :projects, :initial_story_points, :integer, :null => true
  end
end
