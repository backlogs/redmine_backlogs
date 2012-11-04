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

      story = RbStory.find(939)
      puts 939
      pp story.history.history

      story.descendants.each{|c|
        puts "#{c.id} :: #{c.parent_id}"
        pp c.history.history
      }
    end
  end
end
