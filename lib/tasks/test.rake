desc 'Test'

require 'pp'
namespace :redmine do
  namespace :backlogs do
    task :test => :environment do
      project = Project.find_by_name('1_problem')
      pp project.scrum_statistics
      RbSprint.find(:all, :conditions => ['not (sprint_start_date is null or effective_date is null) and project_id = ?', project.id]).each{|sprint|
        #puts "Sprint #{sprint.name} (#{sprint.sprint_start_date} - #{sprint.effective_date})"
        #puts sprint.burndown.data.inspect

#        sprint.stories.each{|story|
#          puts "  Story #{story.id.to_s.ljust(4, ' ')} (#{story.story_points.inspect.rjust(5, ' ')} pts) #{story.subject} / #{story.burndown.inspect}"
#          #puts story.burndown.inspect
#        }
#        next
#
#        RbTask.find(:all, :limit => 5, :conditions => ['tracker_id = ? and fixed_version_id = ? and estimated_hours <> 0', RbTask.tracker, sprint.id]).each{|task|
#          puts "Task: #{task.subject}"
#          puts task.burndown.inspect
#        }
      }
    end
  end
end
