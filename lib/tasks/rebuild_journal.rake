namespace :redmine do
  namespace :backlogs do
    desc "Rebuild unified journal"
    task :rebuild_journal => :environment do
      if ENV['limit'] =~ /^[0-9]+$/
        limit = Integer(ENV['limit'])
      else
        limit = nil
      end

      reset = (ENV['reset'] == 'true')
      RbJournal.delete_all if reset || limit.nil?

      if limit.nil?
        issues = Issue.all
      else
        issues = Issue.find(:all, :conditions => 'rb_journals.issue_id is null', :joins => 'left join rb_journals on issues.id = rb_journals.issue_id', :limit => limit)
      end

      issues = issues.to_a

      if issues.size > 0
        puts "Migrating journals for #{issues.size} issues. This will take a while. Sorry."
      else
        puts "Nothing to do"
      end

      migrated = 0
      issues.in_groups_of(50, false) do |chunk|
        report = true
        b = Benchmark.measure {
          chunk.each{|issue|
            puts "Issue #{issue.id} + #{chunk.size - 1} others" if report && limit
            report = false
            RbJournal.rebuild(issue)
          }
        }

        migrated += chunk.size
        speed = chunk.size.to_f / b.real
        puts "#{migrated} issues migrated, (#{Integer(speed)} issues/second), estimated time remaining: #{Integer(((issues.size - migrated) + 1) / speed)}s"
      end
    end
  end
end
