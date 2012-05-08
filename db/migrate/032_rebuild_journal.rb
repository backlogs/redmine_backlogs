require 'benchmark'

class RebuildJournal < ActiveRecord::Migration
  def self.up
    RbJournal.delete_all

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

    add_index :rb_journals, :issue_id 
    add_index :rb_journals, :property 
    add_index :rb_journals, :timestamp 
    add_index :rb_journals, :value 
    add_index :rb_journals, [:issue_id, :property, :value]

    puts "Priming stats cache"
    EnabledModule.find(:all, :conditions => ["enabled_modules.name = 'backlogs' and status = ?", Project::STATUS_ACTIVE], :include => :project, :joins => :project).each{|mod|
      puts mod.project.name
      mod.project.scrum_statistics
    }
  end

  def self.down
    #pass
  end
end
