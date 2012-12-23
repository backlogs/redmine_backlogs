desc 'CP Test'

namespace :redmine do
  namespace :backlogs do
    task :cp => :environment do
      RbIssueHistory.rebuild
    end
  end
end
