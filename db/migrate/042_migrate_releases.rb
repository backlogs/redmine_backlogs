class MigrateReleases < ActiveRecord::Migration
  def self.up
    add_column :releases, :status, :string, :null => false, :default => 'open'
    add_column :releases, :description, :text

    puts "Migrating implicit releases..."
    RbRelease.integrate_implicit_stories
    puts "Migration of implicit releases done."

    if ActiveRecord::Base.connection.table_exists?('release_burndown_days')
      drop_table :release_burndown_days
    end
    remove_column :releases, :initial_story_points
  end

  def self.down
    puts "Reverting irreversible migration"
  end
end
