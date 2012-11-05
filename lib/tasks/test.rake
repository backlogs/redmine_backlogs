desc 'Test'

require 'pp'
require 'date'

begin
  require 'timecop' # redmine pre-loads all tasks
rescue LoadError
end


namespace :redmine do
  namespace :backlogs do
    task :test => :environment do
      RbIssueHistory.rebuild
    end
  end
end
