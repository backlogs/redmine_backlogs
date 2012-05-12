require 'benchmark'

class ExpandedJournal < ActiveRecord::Migration
  def self.up
    create_table :rb_journals do |t|
      t.column :issue_id, :integer, :null => false
      t.column :property, :string, :null => false, :limit => 50
      t.column :timestamp, :datetime, :null => false
      t.column :value, :string, :limit => 50
    end
  end

  def self.down
    drop_table :rb_journals
  end
end
