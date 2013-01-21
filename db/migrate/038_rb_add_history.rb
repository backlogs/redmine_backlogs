require 'benchmark'
require 'yaml'

class RbAddHistory < ActiveRecord::Migration
  def self.up
    #drop_table :rb_journals if ActiveRecord::Base.connection.table_exists?('rb_journals')

    unless ActiveRecord::Base.connection.table_exists?('rb_issue_history')
      create_table :rb_issue_history do |t|
        t.column :issue_id,    :integer, :default => 0,  :null => false
        t.text   :history
      end
      add_index :rb_issue_history, :issue_id, :unique => true
    end

    unless ActiveRecord::Base.connection.table_exists?('rb_sprint_burndown')
      create_table :rb_sprint_burndown do |t|
        t.column :version_id,    :integer, :default => 0,  :null => false
        t.text   :stories
        t.text   :burndown
        t.timestamps
      end
      add_index :rb_sprint_burndown, :version_id, :unique => true
    end

    #migration 40 wants to add release-issue relation. issue_history tracks this, so the relation needs to be there before a history migration is performed
    unless ActiveRecord::Base.connection.column_exists?(:issues, :release_id)
      add_column :issues, :release_id, :integer
    end

    if ENV['rbl_migration_ignore_historic_history'] =~ /^yes$/i
      puts "You have chosen to ignore the existing history and to start anew. Fine by me, but it will take a while for the charts to become meaningful. DO NOT POST ISSUES ABOUT THE CHARTS BEING WRONG until you have at least 5 sprints of data since this installation."
    else
      puts "Rebuilding history..."
      RbIssueHistory.rebuild
      puts "Rebuild done"
    end
  end

  def self.down
  end
end
