require "./plugins/redmine_backlogs/db/migrate/047_add_issues_rbcache.rb"

class AddIssuesReleaseDayCache < ActiveRecord::Migration
  def self.up
    create_table :rb_release_burnchart_day_caches, :id => false do |t|
      t.column :issue_id, :integer, :null => false
      t.column :release_id, :integer, :null => false
      t.column :day, :date, :null => false
      t.column :total_points, :float, :default => 0, :null => false
      t.column :added_points, :float, :default => 0, :null => false
      t.column :closed_points, :float, :default => 0, :null => false
    end
    add_index :rb_release_burnchart_day_caches, :issue_id
    add_index :rb_release_burnchart_day_caches, :release_id
    add_index :rb_release_burnchart_day_caches, :day

    AddIssuesRbcache.new.down
  end

  def self.down
    remove_index :rb_release_burnchart_day_caches, :column => :issue_id
    remove_index :rb_release_burnchart_day_caches, :column => :release_id
    remove_index :rb_release_burnchart_day_caches, :column => :day
    drop_table :rb_release_burnchart_day_caches
    AddIssuesRbcache.new.up
  end
end
