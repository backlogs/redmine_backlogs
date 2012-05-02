def get_project(identifier)
  Project.find(identifier)
end

def time_offset(o)
  o = o.to_s.strip
  return nil if o == ''

  m = o.match(/^(-?)(([0-9]+)d)?(([0-9]+)h)?(([0-9]+)m)?$/)
  raise "Not a valid offset spec '#{o}'" unless m && o != '-'
  _, sign, _, d, _, h, _, m = m.to_a

  return ((((d.to_i * 24) + h.to_i) * 60) + m.to_i) * 60 * (sign == '-' ? -1 : 1)
end

def initialize_story_params(project_id = nil)
  @story = HashWithIndifferentAccess.new(RbStory.new.attributes)
  @story['project_id'] = project_id ? Project.find(project_id).id : @project.id
  @story['tracker_id'] = RbStory.trackers.first
  @story['author_id']  = @user.id
  @story
end

def initialize_task_params(story_id)
  params = HashWithIndifferentAccess.new(RbTask.new.attributes)
  params['project_id'] = RbStory.find_by_id(story_id).project_id
  params['tracker_id'] = RbTask.tracker
  params['author_id']  = @user.id
  params['parent_issue_id'] = story_id
  params['status_id'] = IssueStatus.find(:first).id
  params
end

def sprint_id_from_name(name)
  sprint = RbSprint.find_by_name(name)
  raise "No sprint by name #{name}" unless sprint
  return sprint.id
end

def initialize_impediment_params(attributes)
  params = HashWithIndifferentAccess.new(RbTask.new.attributes).merge(attributes)
  params['tracker_id'] = RbTask.tracker
  params['author_id']  = @user.id
  params['status_id'] = IssueStatus.default.id
  params['project_id'] = Version.find(params['fixed_version_id']).project.id if params['fixed_version_id']
  params
end

def initialize_sprint_params
  params = HashWithIndifferentAccess.new(RbSprint.new.attributes)
  params['project_id'] = @project.id
  params
end

def login_as_product_owner
  visit url_for(:controller => 'account', :action=>'login')
  fill_in 'username', :with => 'jsmith'
  fill_in 'password', :with => 'jsmith'
  page.find(:xpath, '//input[@name="login"]').click
  @user = User.find(:first, :conditions => "login='jsmith'")
end

def login_as_scrum_master
  visit url_for(:controller => 'account', :action=>'login')
  fill_in 'username', :with => 'jsmith'
  fill_in 'password', :with => 'jsmith'
  page.find(:xpath, '//input[@name="login"]').click
  @user = User.find(:first, :conditions => "login='jsmith'")
end

def login_as_team_member
  visit url_for(:controller => 'account', :action=>'login')
  fill_in 'username', :with => 'jsmith'
  fill_in 'password', :with => 'jsmith'
  page.find(:xpath, '//input[@name="login"]').click
  @user = User.find(:first, :conditions => "login='jsmith'")
end

def login_as_admin
  visit url_for(:controller => 'account', :action=>'login')
  fill_in 'username', :with => 'admin'
  fill_in 'password', :with => 'admin'
  page.find(:xpath, '//input[@name="login"]').click
  @user = User.find(:first, :conditions => "login='admin'")
end  

def task_position(task)
  p1 = task.story.tasks.select{|t| t.id == task.id}[0].rank
  p2 = task.rank
  p1.should == p2
  return p1
end

def story_position(story)
  p1 = RbStory.backlog(:project_id => story.fixed_version_id ? nil : story.project.id, :sprint_id => story.fixed_version_id).select{|s| s.id == story.id}[0].rank
  p2 = story.rank
  p1.should == p2

  RbStory.at_rank(p1, :project_id => story.project_id, :sprint_id => story.fixed_version_id).id.should == story.id
  return p1
end

def logout
  visit url_for(:controller => 'account', :action=>'logout')
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

def story_before(pos)
  pos= pos.to_s

  if pos == '' # add to the bottom
    prev = Issue.find(:first, :conditions => ['not position is null'], :order => 'position desc')
    return prev ? prev.id : nil
  end

  pos = pos.to_i

  # add to the top
  return nil if pos == 1

  # position after
  stories = [] + Issue.find(:all, :order =>  'position asc')
  stories.size.should be > (pos - 2)
  return stories[pos - 2].id
end
