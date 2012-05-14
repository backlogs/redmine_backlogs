require 'benchmark'

class RebuildJournal < ActiveRecord::Migration
  def self.up
    add_index :rb_journals, :issue_id 
    add_index :rb_journals, :property 
    add_index :rb_journals, :timestamp 
    add_index :rb_journals, :value 
    add_index :rb_journals, [:issue_id, :property, :value]
  end

  def self.down
    #pass
  end
end
