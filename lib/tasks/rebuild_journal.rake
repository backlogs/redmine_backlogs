namespace :redmine do
  namespace :backlogs do
    desc "Rebuild unified journal"
    task :rebuild_journal => :environment do
      RbIssueHistory.rebuild
    end
  end
end
