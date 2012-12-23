#!/home/hnse/.rvm/gems/ruby-1.9.3-p194@redmine/bin/rails runner
require 'pp'

s = RbSprint.find(:first, :conditions => 'not (sprint_start_date is null and effective_date is null)')
t = RbTask.find(:first, :conditions => ['tracker_id = ? and fixed_version_id = ?', RbTask.tracker, s.id])
b = t.burndown

pp b
