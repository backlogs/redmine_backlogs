desc 'Test'

require 'pp'
require 'date'
require 'timecop'

def slim(x)
  {:date => x[:date], :estimated_hours => x[:estimated_hours], :remaining_hours => x[:remaining_hours], :hours => x[:hours]}
end

namespace :redmine do
  namespace :backlogs do
    task :test => :environment do
      story = RbStory.find(939)
      puts 939


      puts story.history.history.collect{|x| slim(x) }.inspect

      story.descendants.each{|c|
        puts "#{c.id} :: #{c.parent_id}"
        puts c.history.history.collect{|x| slim(x) }.inspect
      }
    end
  end
end
