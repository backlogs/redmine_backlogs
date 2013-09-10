require 'timecop'
require 'chronic'
require 'cucumber/ast/background'
require 'benchmark'

class Time
  def force_tz(tz=nil)
    tz = ActiveSupport::TimeZone['UTC'] if tz.nil?
    tz.local(self.year, self.month, self.day, self.hour, self.min, self.sec)
  end
end

#module Cucumber
#  module Ast
#    class Background #:nodoc:
#      alias_method :accept_org, :accept
#
#      def accept(visitor)
#        #cache_file = self.feature.file + '.background'
#        #return backlogs_load(cache_file) if File.exist?(cache_file) && File.mtime(cache_file) > File.mtime(self.feature.file)
#        total = Benchmark.measure{ accept_org(visitor) }.total
#        puts "Background #{File.basename(self.feature.file, File.extname(self.feature.file))}: #{total}s"
#        #backlogs_dump(cache_file) if !File.exist?(cache_file) || File.mtime(cache_file) < File.mtime(self.feature.file)
#      end
#
#      def backlogs_dump(filename)
#        skip_tables = ["schema_info"]
#        dump = {}
#        (ActiveRecord::Base.connection.tables - skip_tables).each{|table_name|
#          dump[table_name] = ActiveRecord::Base.connection.select_all("select * from #{table_name}")
#        }
#        File.open(filename, 'w'){|file| file.write(dump.to_yaml)}
#      end
#
#      def backlogs_load(filename)
#        dump = YAML::load_file(filename)
#        dump.each_pair{|table_name, rows|
#          ActiveRecord::Base.connection.execute("delete from #{table_name}")
#          next unless rows.size > 0
#          columns = rows[0].keys
#          sql = "insert into #{table_name} (#{columns.join(',')}) values (#{columns.collect{|c| '%s'}.join(',')})"
#          rows.each{|row|
#            ActiveRecord::Base.connection.execute(sql % columns.collect{|c| ActiveRecord::Base::sanitize(row[c])})
#          }
#        }
#      end
#    end
#  end
#end

def get_project(identifier)
  Project.find(identifier)
end

def get_releases(list)
  list.split(',').collect{|r| RbRelease.find_by_name(r).id}
end

def get_tracker(identifier)
  Tracker.find_by_name(identifier)
end


def current_sprint(name = nil)
  if name.is_a?(Symbol)
    case name
    when :keep
      # keep
    else
      raise "Unexpected command #{name.inspect}"
    end
  elsif name.is_a?(String)
    @sprint =  RbSprint.find_by_name(name)
  elsif name.nil?
    @sprint = @sprint ? RbSprint.find_by_id(@sprint.id) : nil
  else
    raise "Unexpected #{name.class}"
  end
  return @sprint
end

def verify_request_status(status)
  if page.driver.respond_to?('response') # javascript drivers has no response
    page.driver.response.status.should equal(status),\
      "Request returned #{page.driver.response.status} instead of the expected #{status}: "\
      "#{page.driver.response.status}\n"\
      "#{page.driver.response.body}"
  else
    true
  end
end

def set_now(time, options={})
  return if time.to_s == ''
  raise "options must be a hash" unless options.is_a?(Hash)

  sprint = options.delete(:sprint)
  reset = options.delete(:reset)
  msg = options.delete(:msg).to_s

  raise "Unexpected options: #{options.keys.inspect}" unless options.size == 0

  msg = "#{msg}: " unless msg == ''
  tz = RbIssueHistory.burndown_timezone

  if (time.is_a?(Integer) || time =~ /^[0-9]+$/) && sprint
    day = Integer(time)

    if day < 0
      time = sprint.days[1].to_time.force_tz(tz) + (day * 24*60*60)
    else
      time = sprint.days[day].to_time.force_tz(tz)
    end
    time += 60*60

    # if we're setting the date to today again, don't do anything
    return if time.to_date == tz.today #Date.today is not utc. its local. Date.current might be.
  else
    Chronic.time_class = tz #convince chronic to use time zone
    time = Chronic.parse(time)
  end
  raise "#{msg}Time #{time} is not in timezone #{tz}" unless time.utc_offset == tz.utc_offset

  if reset
    # don't test anything, just set the time
  else
    # Time zone must be set correctly, or ActiveRecord will store local, but retrieve UTC, which screws to Time.to_date. WTF people.
    now = tz.now

    timediff = now - time
    raise "#{msg}You may not travel back in time (it is now #{now}, and you want it to be #{time}" if timediff > 0 #WHY? i am testing, ain't i?
  end

  Timecop.travel(time)
end

def story_after(rank, project, sprint=nil)
  return nil if rank.blank?

  rank = rank.to_i if rank.is_a?(String) && rank =~ /^[0-9]+$/

  nxt = RbStory.find_by_rank(rank, RbStory.find_options(:project => project, :sprint => sprint))
  return nil if nxt.nil?

  return nxt.id
end

def time_offset(o)
  o = o.to_s.strip
  return nil if o == ''

  m = o.match(/^(-?)(([0-9]+)d)?(([0-9]+)h)?(([0-9]+)m)?$/)
  raise "Not a valid offset spec '#{o}'" unless m && o != '-'
  _, sign, _, d, _, h, _, m = m.to_a

  return ((((d.to_i * 24) + h.to_i) * 60) + m.to_i) * 60 * (sign == '-' ? -1 : 1)
end

def offset_to_hours(o)
  # seconds to hours
  return o/60/60
end

def initialize_story_params(project_id = nil)
  @story = HashWithIndifferentAccess.new(RbStory.new.attributes)
  @story['project_id'] = project_id ? Project.find(project_id).id : @project.id
  @story['tracker_id'] = RbStory.trackers.include?(Backlogs.setting[:default_story_tracker]) ? Backlogs.setting[:default_story_tracker] : RbStory.trackers.first 
  @story['author_id']  = @user.id
  @story
end

def initialize_task_params(story_id)
  params = HashWithIndifferentAccess.new(RbTask.new.attributes)
  params['project_id'] = RbStory.find_by_id(story_id).project_id
  params['tracker_id'] = RbTask.tracker
  params['author_id']  = @user.id
  params['parent_issue_id'] = story_id
  params['status_id'] = IssueStatus.default.id
  params
end

def sprint_id_from_name(name)
  sprint = RbSprint.find_by_name(name)
  raise "No sprint by name #{name}" unless sprint
  return sprint.id
end

def initialize_impediment_params(attributes)
  #requires project_id in attributes (pa sharing)
  params = HashWithIndifferentAccess.new(RbTask.new.attributes).merge(attributes)
  params['tracker_id'] = RbTask.tracker
  params['author_id']  = @user.id
  params['status_id'] = IssueStatus.default.id
  params
end

def initialize_sprint_params
  params = HashWithIndifferentAccess.new(RbSprint.new.attributes)
  params['project_id'] = @project.id
  params
end

def login_as(user, password)
  visit url_for(:controller => 'account', :action=>'login', :only_path=>true)
  fill_in 'username', :with => user
  fill_in 'password', :with => password
  page.find(:xpath, '//input[@name="login"]').click
  @user = User.find(:first, :conditions => "login='"+user+"'")
end

def login_as_product_owner
  login_as('jsmith', 'jsmith')
  setup_permissions('product owner')
end

def login_as_scrum_master
  login_as('jsmith', 'jsmith')
  setup_permissions('scrum master')
end

def login_as_team_member
  login_as('jsmith', 'jsmith')
  setup_permissions('team member')
end

def login_as_admin
  login_as('admin', 'admin')
end

def setup_permissions(typ)
  role = Role.find(:first, :conditions => "name='Manager'")
  if typ == 'scrum master'
    role.permissions << :view_master_backlog
    role.permissions << :view_releases
    role.permissions << :view_taskboards
    role.permissions << :update_sprints
    role.permissions << :update_stories
    role.permissions << :create_impediments
    role.permissions << :update_impediments
    role.permissions << :subscribe_to_calendars
    role.permissions << :view_wiki_pages        # NOTE: This is a Redmine core permission
    role.permissions << :edit_wiki_pages        # NOTE: This is a Redmine core permission
    role.permissions << :create_sprints
  elsif typ == 'team member'
    role.permissions << :view_master_backlog
    role.permissions << :view_releases
    role.permissions << :view_taskboards
    role.permissions << :create_tasks
    role.permissions << :update_tasks
  else #product owner
    role.permissions << :view_master_backlog
    role.permissions << :create_stories
    role.permissions << :update_stories
    role.permissions << :view_releases
    role.permissions << :modify_releases
    role.permissions << :view_scrum_statistics
    role.permissions << :configure_backlogs
  end
  role.save!
  
  @projects.each{|project|
    m = Member.new(:user => @user, :roles => [role])
    project.members << m
  }
end

def task_position(task)
  p1 = task.story.tasks.select{|t| t.id == task.id}[0].rank
  p2 = task.rank
  p1.should == p2
  return p1
end

def story_position(story)
  p1 = RbStory.backlog(story.project, story.fixed_version_id, nil).select{|s| s.id == story.id}[0].rank
  p2 = story.rank
  p1.should == p2

  s2 = RbStory.find_by_rank(p1, RbStory.find_options(:project => @project, :sprint => current_sprint))
  s2.should_not be_nil
  s2.id.should == story.id

  return p1
end

def logout
  visit url_for(:controller => 'account', :action=>'logout', :only_path=>true)
  @user = nil
end

def show_table(title, header, data)
  sizes = data.transpose.collect{|d| d.collect{|s| s.to_s.length}.max }
  sizes = header.zip(sizes).collect{|hs| [hs[0].length, hs[1]].max }
  sizes = sizes.zip(header).collect{|sh| sh[1].is_a?(Array) ? sh[1][1] : sh[0] }

  header = header.collect{|h| h.is_a?(Array) ? h[0] : h}

  header = header.zip(sizes).collect{|hs| hs[0].ljust(hs[1]) }

  puts "\n#{title}"
  puts "\t| #{header.join(' | ')} |"

  data.each {|row|
    row = row.zip(sizes).collect{|rs| rs[0].to_s[0,rs[1]].ljust(rs[1]) }
    puts "\t| #{row.join(' | ')} |"
  }

  puts "\n\n"
end

def check_backlog_menu_new_story(links, project)
  found = false
  if links.length==1
    project_id = @project.id
    found = true if project_id.to_i == project.id
  else
    links.each{|a|
      project_id = a[:class][%r[\d+$]]
      found = true if project_id.to_i == project.id
    }
  end
  return found
end

When /^(?:|I )select multiple "([^"]*)" from "([^"]*)"(?: within "([^"]*)")?$/ do |value, field, selector|
  options = page.find_field(field).all("option").collect(&:text)
  with_scope(selector) do
    # clear all options
    options.each{|v|
      unselect(v, :from => field)
    }
    # Select the requested options
    value.split(",").each{|v|
      select(v, :from => field)
    }
  end
end

