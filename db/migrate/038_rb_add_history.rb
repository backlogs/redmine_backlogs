require 'benchmark'
require 'yaml'

class RbAddHistory < ActiveRecord::Migration
  def self.up
    drop_table :rb_journals

    create_table :rb_issue_history, :id => false do |t|
      t.column :issue_id,    :integer, :default => 0,  :null => false
      t.text   :history
    end

    RbIssueHistory.rebuild
    add_index :rb_history, :issue_id, :unique => true
  end

  def self.down
  end
end
