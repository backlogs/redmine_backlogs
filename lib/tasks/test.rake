desc 'Test'

require 'pp'
require 'date'
require 'timecop'

namespace :redmine do
  namespace :backlogs do
    task :test => :environment do
      Time.zone = 'Amsterdam'
      project = Project.find_by_name('1_problem')
      pp project.scrum_statistics
      Timecop.travel(Time.local(2012, 7, 27, 8, 0, 0)) do
        pp project.scrum_statistics
      end

      expected = {
        39  => 46.5,
        38  => 31.5,
        36  => 31.0,
        33  => 38.0,
        32  => 54.0,
      }
      Timecop.travel(Time.local(2012, 7, 27, 8, 0, 0)) do
        active = RbSprint.find(:first,
                               :conditions => ["project_id = ?
                                                and status = 'open'
                                                and not (sprint_start_date is null or effective_date is null)
                                                and ? between sprint_start_date and effective_date", project.id, Date.today])
        past_sprints = RbSprint.find(:all,
                :conditions => ["project_id = ? and not(effective_date is null or sprint_start_date is null) and effective_date < ?", project.id, Date.today],
                :order => "effective_date desc",
                :limit => 5).select(&:has_burndown?)
        past_sprints.collect{|sprint|
          raise "Unexpected sprint #{sprint.id}" unless expected[sprint.id]
#          next unless sprint.id == 38
#          #puts sprint.burndown.data[:points_committed].inspect
#          stories = sprint.stories.collect{|s| s.id}
#
          sprint.burndown.direction = :up
#          total = 0
#          RbStory.find(:all, :conditions => ['id in (?)', sprint.burndown.stories]).each{|story|
#            h = story.history.history[-1]
#            #puts "#{story.id}, points = #{h[:status_success] ? h[:story_points] : '-'}, success = #{h[:status_success]}"
#            bd = story.burndown(sprint)
#            points = bd ? bd[:points_accepted] : nil
#            raise "Story without burndown #{bd.inspect}/#{h.inspect}" if story.is_story? && (!points || h[:tracker] != :story)
#            points = points[-1] if points
#            next if bd.nil? && !story.is_task? && !story.is_story?
#            next if h[:tracker] == :task && story.is_task?
#
#            raise "Task #{story.id} with burndown #{story.history.history.inspect}" if story.is_task? && points
#            raise "#{story.id} not a sprint story" unless stories.include?(story.id) || points.nil?
#            next if points.nil?
#            puts "#{story.id}, points = #{h[:status_success] ? h[:story_points] : "<#{h[:story_points]}>"}, success = #{h[:status_success]}"
#            raise "#{story.id}: #{points} vs. #{h[:status_success] ? h[:story_points] : '0'}" if points != (h[:status_success] ? h[:story_points] : 0)
#            total += points
#          }
#
          puts "sprint #{sprint.id}, burndown result: #{sprint.burndown.data[:points_accepted][-1]}, expected: #{expected[sprint.id]}" if sprint.burndown.data[:points_accepted][-1] != expected[sprint.id]
        }
      end
    end
  end
end

#Going back to 27-07-2012 gives me the following:
#active: 40
#Past sprints:
#39  - 46,5 points
#38  - 31,5 points
#36  - 31 points
#33  - 38 points
#32  - 54 points
#
#This should be an average of 40,2 points per sprint.
#I manually found the closed stories of each sprint in the issues view and calculated the average.
#If I remove sprint ID 32 and recalculate I get an average around 30 points, but the scrum statistics says around 19.
