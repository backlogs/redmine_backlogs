class AddInitialStoryPointsToProject < ActiveRecord::Migration
  def self.up
    add_column :projects, :initial_story_points, :integer, :null => true
  end

  def self.down
    remove_column :projects, :initial_story_points
  end
end
