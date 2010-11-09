class AddInitialStoryPointsToProject < ActiveRecord::Migration
  def self.up
    add_column :projects, :initial_story_points, :integer, :null => true
  end

  def self.down
    drop_column :projects, :initial_story_points
  end
end
