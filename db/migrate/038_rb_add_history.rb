require 'benchmark'
require 'yaml'

class RbAddHistory < ActiveRecord::Migration
  extend Backlogs::Migrate

  def self.up
    drop_table :rb_journals if ActiveRecord::Base.connection.table_exists?('rb_journals')

    self.rb_common_migrate_up

    puts "Rebuilding history..."
    RbIssueHistory.rebuild
    puts "Rebuild done"
  end

  def self.down
  end
end
