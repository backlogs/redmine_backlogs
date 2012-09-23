desc 'Test'

require 'pp'
require 'date'
require 'timecop'

namespace :redmine do
  namespace :backlogs do
    task :test => :environment do
      project = Project.find_by_name('1_problem')
      user = User.find(:first)

      raise "No project" unless project

      start_date = Date.today - 10
      end_date = Date.today - 2

      story_id = nil
      sprint = nil
      Timecop.travel(start_date.to_time) do
        sprint = RbSprint.new(:project_id => project.id, :name => SecureRandom.uuid, :sprint_start_date => start_date, :effective_date => end_date)
        sprint.save!

        story = RbStory.new(:author_id => user.id, :tracker_id => RbStory.trackers[0], :project_id => project.id, :fixed_version_id => sprint.id, :subject => Time.now.to_s, :story_points => 5.0, :estimated_hours => 10, :remaining_hours => 10.0)
        story.save!
        story_id = story.id
        puts story_id
      end

      step = 5
      hours = 60 * 60
      (start_date + 1 .. start_date + step + 1).to_a.each_with_index{|day, i|
        Timecop.travel(day.to_time + (4 * hours)) do
          story = RbStory.find(story_id)
          story.init_journal(user)
          story.remaining_hours = step - i
          story.save
        end
      }
      story = RbStory.find(story_id)
      pp story.burndown
    end
  end
end
