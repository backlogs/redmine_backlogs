desc 'Test'

require 'pp'
namespace :redmine do
  namespace :backlogs do
    task :test => :environment do
      s = RbSprint.find(:first, :conditions => 'not (sprint_start_date is null and effective_date is null)')
      t = RbTask.find(:first, :conditions => ['tracker_id = ? and fixed_version_id = ? and estimated_hours <> 0', RbTask.tracker, s.id])
      b = t.burndown

      pp b
    end
  end
end
