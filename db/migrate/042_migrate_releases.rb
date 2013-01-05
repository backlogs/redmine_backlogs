class MigrateReleases < ActiveRecord::Migration
  def self.up
    puts "Migrating implicit releases..."
    RbRelease.integrate_implicit_stories
    puts "Migration of implicit releases done."

    drop_table :release_burndown_days
    remove_column :releases, :initial_story_points
  end

  def self.down
  end
end
