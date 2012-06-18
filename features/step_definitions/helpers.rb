def get_project(identifier)
  Project.find(:first, :conditions => "identifier='#{identifier}'")
end

def verify_request_status(status)
  page.driver.response.status.should equal(status),\
    "Request returned #{page.driver.response.status} instead of the expected #{status}: "\
    "#{page.driver.response.status}\n"\
    "#{page.driver.response.body}"
end

def story_before(rank, project, sprint=nil)
  return nil if rank.blank?

  rank = rank.to_i if rank.is_a?(String) && rank =~ /^[0-9]+$/
  return nil if rank == 1

  prev = RbStory.find_by_rank(rank - 1, RbStory.find_options(:project => project, :sprint => sprint))
  prev.should_not be_nil

  return prev.id
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

def initialize_story_params
  @story = HashWithIndifferentAccess.new(RbStory.new.attributes)
  @story['project_id'] = @project.id
  @story['tracker_id'] = RbStory.trackers.first
  @story['author_id']  = @user.id
  @story
end

def initialize_task_params(story_id)
  params = HashWithIndifferentAccess.new(RbTask.new.attributes)
  params['project_id'] = @project.id
  params['tracker_id'] = RbTask.tracker
  params['author_id']  = @user.id
  params['parent_issue_id'] = story_id
  params['status_id'] = IssueStatus.default.id
  params
end

def initialize_impediment_params(sprint_id)
  params = HashWithIndifferentAccess.new(RbTask.new.attributes)
  params['project_id'] = @project.id
  params['tracker_id'] = RbTask.tracker
  params['author_id']  = @user.id
  params['fixed_version_id'] = sprint_id
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
end

def login_as_scrum_master
  login_as('jsmith', 'jsmith')
end

def login_as_team_member
  login_as('jsmith', 'jsmith')
end

def login_as_admin
  login_as('admin', 'admin')
end  

def task_position(task)
  p1 = task.story.tasks.select{|t| t.id == task.id}[0].rank
  p2 = task.rank
  p1.should == p2
  return p1
end

def story_position(story)
  p1 = RbStory.backlog(story.project, story.fixed_version_id).select{|s| s.id == story.id}[0].rank
  p2 = story.rank
  p1.should == p2

  s2 = RbStory.find_by_rank(p1, RbStory.find_options(:project => @project, :sprint => @sprint))
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

def assert_page_loaded(page)
  if page.driver.respond_to?('response') # javascript drivers has no response
    page.driver.response.status.should == 200
  else
    true # no way to check javascript driver page status yet
  end
end

