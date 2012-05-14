namespace :redmine do
  namespace :backlogs do
    desc "Rebuild unified journal"
    task :rebuild_journal => :environment do
      project = ENV['project'].to_s.strip
      project = nil if project == '' || project == '*'

      if project && Project.count(:conditions => ['identifier = ?', project]) != 1
        puts "Project #{project.inspect} not found. Available projects:"
        Project.all.each{|p| puts "* #{p.identifier}" }
        exit
      end

      Issue.transaction do
        if project
          RbJournal.delete_all(['issue_id in (select issues.id from issues join projects on issues.project_id = projects.id and projects.identifier = ?)', project])
          issues = Issue.find(:all, :joins => :project, :conditions => ['projects.identifier = ?', project])
        else
          RbJournal.delete_all
          issues = Issue.all
        end

        issues = issues.to_a

        puts "Migrating journals for #{issues.size} issues. This will take a while. Sorry."
        migrated = 0
        issues.in_groups_of(50, false) do |chunk|
          b = Benchmark.measure { chunk.each{|issue| RbJournal.rebuild(issue) } }
  
          migrated += chunk.size
          speed = chunk.size.to_f / b.real
          puts "#{migrated} issues migrated, (#{Integer(speed)} issues/second), estimated time remaining: #{Integer(((issues.size - migrated) + 1) / speed)}s"
        end
      end
    end
  end
end
