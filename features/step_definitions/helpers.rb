def get_project(identifier)
  Project.find(identifier)
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
  params['project_id'] = @project.id
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
  params['status_id'] = IssueStatus.default
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

def show_table(header, data)
  header = header.collect{|h| [h[0].ljust(h[1]), h[1]] }

  puts "\n"
  puts "\t| #{header.collect{|h| h[0] }.join(' | ')} |"

  data.each {|row|
    row = 0.upto(row.size - 1).collect{|i| row[i].to_s[0,header[i][1]].ljust(header[i][1]) }
    puts "\t| #{row.join(' | ')} |"
  }

  puts "\n\n"
end

def show_projects(p = nil, l = -1)
  puts "#{'  ' * l}#{p.identifier}" if p
  puts "\n" unless p

  (p ? p.children : Project.roots).each {|project|
    show_projects(project, l + 1)
  }
end
