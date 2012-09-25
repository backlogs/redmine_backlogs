desc 'Test'

require 'pp'
require 'date'
require 'timecop'

namespace :redmine do
  namespace :backlogs do
    task :test => :environment do
      hours = 60 * 60

      Time.zone = 'Amsterdam'

      project = Project.find_by_name('1_problem')
      user = User.find(:first)

      raise "No project" unless project

      start_date = Date.today - 20
      end_date = Date.today - 2

      story_id = nil
      sprint = nil
      Timecop.travel(start_date.to_time + 1 * hours) do
        sprint = RbSprint.new(:project_id => project.id, :name => SecureRandom.uuid, :sprint_start_date => start_date, :effective_date => end_date)
        sprint.save!

        story = RbStory.new(:author_id => user.id, :tracker_id => RbStory.trackers[0], :project_id => project.id, :fixed_version_id => sprint.id, :subject => Time.now.to_s, :story_points => 5.0, :estimated_hours => 10, :remaining_hours => 10.0)
        story.save!
        story_id = story.id
        puts story_id
      end

      remaining = 5
      sprint.days.each_with_index{|day, i|
        next if i == 0
        Timecop.travel(day.to_time + (4 * hours)) do
          story = RbStory.find(story_id)
          story.init_journal(user)
          story.remaining_hours = remaining
          story.save
        end
        break if remaining == 0
        remaining -= 1
      }
      story = RbStory.find(story_id)
      puts "#{start_date} -- #{end_date}"
      puts sprint.days.inspect
      pp story.burndown

      sprint = RbSprint.find(sprint.id) # refresh, because it points to a stale burndown
      puts '------ here we go ----'
      pp sprint.burndown.data
    end
  end
end
