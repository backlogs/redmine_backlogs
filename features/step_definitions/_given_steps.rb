Given /^I am a product owner of the project$/ do
  role = Role.find(:first, :conditions => "name='Manager'")
  role.permissions << :view_master_backlog
  role.permissions << :create_stories
  role.permissions << :update_stories
  role.permissions << :view_releases
  role.permissions << :create_releases
  role.permissions << :update_releases
  role.permissions << :view_scrum_statistics
  role.save!
  login_as_product_owner
end

Given /^I am a scrum master of the project$/ do
  role = Role.find(:first, :conditions => "name='Manager'")
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
  role.save!
  login_as_scrum_master
end

Given /^I am a team member of the project$/ do
  role = Role.find(:first, :conditions => "name='Manager'")
  role.permissions << :view_master_backlog
  role.permissions << :view_releases
  role.permissions << :view_taskboards
  role.permissions << :create_tasks
  role.permissions << :update_tasks
  role.save!
  login_as_team_member
end

Given /^I am logged out$/ do
  logout
end

Given /^I am viewing the master backlog$/ do
  visit url_for(:controller => :projects, :action => :show, :id => @project)
  click_link("Backlogs")
  page.driver.response.status.should == 200
end

Given /^I am viewing the burndown for (.+)$/ do |sprint_name|
  @sprint = Sprint.find(:first, :conditions => ["name=?", sprint_name])
  visit url_for(:controller => :rb_burndown_charts, :action => :show, :sprint_id => @sprint.id)
  page.driver.response.status.should == 200
end

Given /^I am viewing the taskboard for (.+)$/ do |sprint_name|
  @sprint = Sprint.find(:first, :conditions => ["name=?", sprint_name])
  visit url_for(:controller => :rb_taskboards, :action => :show, :sprint_id => @sprint.id)
  page.driver.response.status.should == 200
end

Given /^I set the (.+) of the story to (.+)$/ do |attribute, value|
  if attribute=="tracker"
    attribute="tracker_id"
    value = Tracker.find(:first, :conditions => ["name=?", value]).id
  elsif attribute=="status"
    attribute="status_id"
    value = IssueStatus.find(:first, :conditions => ["name=?", value]).id
  end
  @story_params[attribute] = value
end

Given /^I set the (.+) of the task to (.+)$/ do |attribute, value|
  value = '' if value == 'an empty string'
  @task_params[attribute] = value
end

Given /^I want to create a story$/ do
  @story_params = initialize_story_params
end

Given /^I want to create a task for (.+)$/ do |story_subject|
  story = Story.find(:first, :conditions => ["subject=?", story_subject])
  @task_params = initialize_task_params(story.id)
end

Given /^I want to create an impediment for (.+)$/ do |sprint_subject|
  sprint = Sprint.find(:first, :conditions => { :name => sprint_subject })
  @impediment_params = initialize_impediment_params(sprint.id)
end

Given /^I want to edit the task named (.+)$/ do |task_subject|
  task = Task.find(:first, :conditions => { :subject => task_subject })
  task.should_not be_nil
  @task_params = HashWithIndifferentAccess.new(task.attributes)
end

Given /^I want to edit the impediment named (.+)$/ do |impediment_subject|
  impediment = Task.find(:first, :conditions => { :subject => impediment_subject })
  impediment.should_not be_nil
  @impediment_params = HashWithIndifferentAccess.new(impediment.attributes)
end

Given /^I want to edit the sprint named (.+)$/ do |name|
  sprint = Sprint.find(:first, :conditions => ["name=?", name])
  sprint.should_not be_nil
  @sprint_params = HashWithIndifferentAccess.new(sprint.attributes)
end

Given /^I want to indicate that the impediment blocks (.+)$/ do |blocks_csv|
  blocks_csv = Story.find(:all, :conditions => { :subject => blocks_csv.split(', ') }).map{ |s| s.id }.join(',')
  @impediment_params[:blocks] = blocks_csv
end

Given /^I want to set the (.+) of the sprint to (.+)$/ do |attribute, value|
  value = '' if value == "an empty string"
  @sprint_params[attribute] = value
end

Given /^I want to set the (.+) of the impediment to (.+)$/ do |attribute, value|
  value = '' if value == "an empty string"
  @impediment_params[attribute] = value
end

Given /^I want to edit the story with subject (.+)$/ do |subject|
  @story = Story.find(:first, :conditions => ["subject=?", subject])
  @story.should_not be_nil
  @story_params = HashWithIndifferentAccess.new(@story.attributes)
end

Given /^the (.*) project has the backlogs plugin enabled$/ do |project_id|
  @project = get_project(project_id)

  # Enable the backlogs plugin
  @project.enabled_modules << EnabledModule.new(:name => 'backlogs')

  # Configure the story and task trackers
  story_trackers = Tracker.find(:all).map{|s| "#{s.id}"}
  task_tracker = "#{Tracker.create!(:name => 'Task').id}"
  plugin = Redmine::Plugin.find('redmine_backlogs')
  Setting["plugin_#{plugin.id}"] = {:story_trackers => story_trackers, :task_tracker => task_tracker }

  # Make sure these trackers are enabled in the project
  @project.update_attributes :tracker_ids => (story_trackers << task_tracker)
end

Given /^the project has the following sprints:$/ do |table|
  @project.versions.delete_all
  table.hashes.each do |version|
    version['project_id'] = @project.id
    ['effective_date', 'sprint_start_date'].each do |date_attr|
      version[date_attr] = eval(version[date_attr]).strftime("%Y-%m-%d") if version[date_attr].match(/^(\d+)\.(year|month|week|day|hour|minute|second)(s?)\.(ago|from_now)$/)
    end
    Sprint.create! version
  end
end

Given /^the project has the following stories in the product backlog:$/ do |table|
  @project.issues.delete_all
  prev_id = ''

  table.hashes.each do |story|
    params = initialize_story_params
    params['subject'] = story['subject']
    params['prev_id'] = prev_id

    # NOTE: We're bypassing the controller here because we're just
    # setting up the database for the actual tests. The actual tests,
    # however, should NOT bypass the controller
    s = Story.create_and_position params
    prev_id = s.id
  end
end

Given /^the project has the following stories in the following sprints:$/ do |table|
  @project.issues.delete_all
  prev_id = ''

  table.hashes.each do |story|
    params = initialize_story_params
    params['subject'] = story['subject']
    params['prev_id'] = prev_id
    params['fixed_version_id'] = Sprint.find(:first, :conditions => [ "name=?", story['sprint'] ]).id

    # NOTE: We're bypassing the controller here because we're just
    # setting up the database for the actual tests. The actual tests,
    # however, should NOT bypass the controller
    s = Story.create_and_position params
    prev_id = s.id
  end
end

Given /^the project has the following tasks:$/ do |table|
  table.hashes.each do |task|
    story = Story.find(:first, :conditions => { :subject => task['parent'] })
    params = initialize_task_params(story.id)
    params['subject'] = task['subject']

    # NOTE: We're bypassing the controller here because we're just
    # setting up the database for the actual tests. The actual tests,
    # however, should NOT bypass the controller
    Task.create_with_relationships(params, @user.id, @project.id)
  end
end

Given /^the project has the following impediments:$/ do |table|
  table.hashes.each do |impediment|
    sprint = Sprint.find(:first, :conditions => { :name => impediment['sprint'] })
    blocks = Story.find(:all, :conditions => { :subject => impediment['blocks'].split(', ')  }).map{ |s| s.id }
    params = initialize_impediment_params(sprint.id)
    params['subject'] = impediment['subject']
    params['blocks']  = blocks.join(',')

    # NOTE: We're bypassing the controller here because we're just
    # setting up the database for the actual tests. The actual tests,
    # however, should NOT bypass the controller
    Task.create_with_relationships(params, @user.id, @project.id)
  end
end

Given /^I am viewing the issues list$/ do
  visit url_for(:controller => 'issues', :action=>'index', :project_id => @project)
  page.driver.response.status.should == 200
end

Given /^I have selected card label stock (.+)$/ do |stock|
  Setting.plugin_redmine_backlogs[:card_spec] = stock
end

Given /^I have set my API access key$/ do
  Setting[:rest_api_enabled] = 1
  @user.reload
  @user.api_key.should_not be_nil
  @api_key = @user.api_key
end

Given /^I have guessed an API access key$/ do
  Setting[:rest_api_enabled] = 1
  @api_key = 'guess'
end

Given /^I have set the content for wiki page (.+) to (.+)$/ do |title, content|
  title = Wiki.titleize(title)
  page = @project.wiki.find_page(title)
  if ! page
    page = WikiPage.new(:wiki => @project.wiki, :title => title)
    page.content = WikiContent.new
    page.save
  end

  page.content.text = content
  page.save.should be_true
end

Given /^I have made (.+) the template page for sprint notes/ do |title|
  Setting.plugin_redmine_backlogs = Setting.plugin_redmine_backlogs.merge({:wiki_template => Wiki.titleize(title)})
end

Given /^there are no stories in the project$/ do
  @project.issues.delete_all
end
