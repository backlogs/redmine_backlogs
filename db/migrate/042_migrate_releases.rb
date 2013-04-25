class MigrateReleases < ActiveRecord::Migration
  def self.up
    add_column :releases, :status, :string, :null => false, :default => 'open'
    add_column :releases, :description, :text

    puts "Migrating implicit releases..."
    RbRelease.integrate_implicit_stories
    puts "Migration of implicit releases done."
  end

  def self.down
    remove_columns :releases, :status
    remove_columns :releases, :description
  end
end
