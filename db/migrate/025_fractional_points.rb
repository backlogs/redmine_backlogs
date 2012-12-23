class FractionalPoints < ActiveRecord::Migration
  def self.up
    add_column :issues, :fractional_story_points, :float
    execute "update issues set fractional_story_points = story_points"
    remove_column :issues, :story_points

    add_column :issues, :story_points, :float
    execute "update issues set story_points = fractional_story_points"
    remove_column :issues, :fractional_story_points
  end

  def self.down
    puts "Reverting irreversible migration"
  end
end
