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
      RbStory.all(:conditions => ['fixed_version_id = 89']).each{|story|
        next unless story.is_story?
        puts story.id
        puts story.history.history.inspect
      }
    end
  end
end
