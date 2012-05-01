require 'benchmark'

class ExpandedJournal < ActiveRecord::Migration
  def self.up
    create_table :rb_journals do |t|
      t.column :issue_id, :integer, :null => false
      t.column :property, :string, :null => false
      t.column :timestamp, :datetime, :null => false
      t.column :value, :string
    end

    issues = Issue.all.to_a
    migrated = 0
    puts "Migrating journals for #{issues.size} issues. This will take a while. Sorry."
    issues.in_groups_of(50, false) do |chunk|
      b = Benchmark.measure {
        chunk.each{|issue| RbJournal.rebuild(issue) }
      }

      migrated += chunk.size
      speed = chunk.size.to_f / b.real
      puts "#{migrated} issues migrated, (#{Integer(speed)} issues/second), estimated time remaining: #{Integer(((issues.size - migrated) + 1) / speed)}s"
    end
  end

  def self.down
    #pass
  end
end
