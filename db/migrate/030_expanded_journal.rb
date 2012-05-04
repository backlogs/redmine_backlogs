require 'benchmark'

class ExpandedJournal < ActiveRecord::Migration
  def self.up
    create_table :rb_journals do |t|
      t.column :issue_id, :integer, :null => false
      t.column :property, :string, :null => false
      t.column :timestamp, :datetime, :null => false
      t.column :value, :string
    end
  end

  def self.down
    #pass
  end
end
