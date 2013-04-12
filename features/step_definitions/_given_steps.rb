require 'rubygems'
require 'timecop'
require 'chronic'

Before do
  Timecop.return
  @projects = nil
  @sprint = nil
  @story = nil
  #sanitize settings, they spill over from previous tests
  Backlogs.setting[:include_sat_and_sun] = false
  Backlogs.setting[:sharing_enabled] = false
  Backlogs.setting[:story_follow_task_status] = nil
  Backlogs.setting[:release_burnup_enabled] = 'enabled'
  Time.zone = 'UTC'
end

After do |scenario|
  Timecop.return
end

Given /^I am admin$/ do
  login_as_admin
end

Given /^I am a product owner of the project$/ do
  login_as_product_owner
end

Given /^I am a scrum master of the project$/ do
  login_as_scrum_master
end

#must not login twice on redmine 2.3
Given /^I am a scrum master of all projects$/ do
  setup_permissions('scrum master')
end

Given /^I am a team member of the project$/ do
  login_as_team_member
end

Given /^I am logged out$/ do
  logout
end

Given /^I am viewing the master backlog$/ do
  visit url_for(:controller => :projects, :action => :show, :id => @project.identifier, :only_path=>true)
  verify_request_status(200)
  click_link("Backlogs")
  page.current_path.should == url_for(:controller => :rb_master_backlogs, :action => :show, :project_id => @project.identifier, :only_path=>true)
  verify_request_status(200)
end

Then /^at ([0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2})$/ do |time|
  set_now(time, :msg => "at #{time}")
end
Then /^on ([0-9]{4}-[0-9]{2}-[0-9]{2})$/ do |date|
  set_now(time, :msg => "on #{date}")
end
Then /^after (the current )?sprint(.*)$/ do |current, name|
  raise "Improperly phrased" if (current == '' && name == '') || (current != '' && name != '')
  sprint = current == '' ? RbSprint.find_by_name(name) : current_sprint
  set_now(sprint.effective_date + 1, :msg => "after sprint #{sprint.name}")
end

Given /^the current (time|date) (is|forwards to) (.+)$/ do |what, action, time|
  reset = case action
          when 'is' then true
          when 'forwards to' then false
          else raise "I don't know how to #{action} time"
          end
  set_now(time, :msg => "#{what} #{action} #{time}", :reset => reset)
end

Given /^I am viewing the burndown for (.+)$/ do |sprint_name|
  visit url_for(:controller => :rb_burndown_charts, :action => :show, :sprint_id => current_sprint(sprint_name).id, :only_path=>true)
  verify_request_status(200)
end

Given /^I am viewing the taskboard for (.+)$/ do |sprint_name|
  visit url_for(:controller => :rb_taskboards, :action => :show, :sprint_id => current_sprint(sprint_name).id, :only_path=>true)
  verify_request_status(200)
end

Given /^I am viewing the backlog settings page for project (.*)$/ do |project_name|
  visit url_for(:controller => :projects, :action => :settings, :id => Project.find(project_name).id, :tab => 'backlogs', :only_path=>true)
  verify_request_status(200)
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
  story = RbStory.find(:first, :conditions => ["subject=?", story_subject])
  @task_params = initialize_task_params(story.id)
end

Given /^I want to create an impediment for (.+)$/ do |sprint_subject|
  sprint = RbSprint.find(:first, :conditions => { :name => sprint_subject })
  @impediment_params = initialize_impediment_params(:project_id => sprint.project_id, :fixed_version_id => sprint.id)
end

Given /^I want to create a sprint$/ do
  @sprint_params = initialize_sprint_params
end

Given /^I want to edit the task named (.+)$/ do |task_subject|
  task = RbTask.find(:first, :conditions => { :subject => task_subject })
  task.should_not be_nil
  @task_params = HashWithIndifferentAccess.new(task.attributes)
end

Given /^I want to edit the impediment named (.+)$/ do |impediment_subject|
  impediment = RbTask.find(:first, :conditions => { :subject => impediment_subject })
  impediment.should_not be_nil
  @impediment_params = HashWithIndifferentAccess.new(impediment.attributes)
end

Given /^I want to edit the sprint named (.+)$/ do |name|
  sprint = RbSprint.find(:first, :conditions => ["name=?", name])
  sprint.should_not be_nil
  @sprint_params = HashWithIndifferentAccess.new(sprint.attributes)
end

Given /^I want to indicate that the impediment blocks (.+)$/ do |blocks_csv|
  blocks_csv = RbStory.find(:all, :conditions => { :subject => blocks_csv.split(', ') }).map{ |s| s.id }.join(',')
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
  @story = RbStory.find(:first, :conditions => ["subject=?", subject])
  @story.should_not be_nil
  @story_params = HashWithIndifferentAccess.new(@story.attributes)
end

Given /^backlogs is configured$/ do
  Backlogs.configured?.should be_true
end


Given /^the (.*) project has the backlogs plugin enabled$/ do |project_id|
  @project = get_project(project_id)
  @projects = [] if @projects.nil?
  @projects.push(@project)
  @project.should_not be_nil

  # Enable the backlogs plugin
  @project.enable_module!('backlogs')

  # Configure the story and task trackers
  story_trackers = [(Tracker.find_by_name('Story') || Tracker.create!(:name => 'Story'))]
  task_tracker = (Tracker.find_by_name('Task') || Tracker.create!(:name => 'Task'))

  copy_from = Tracker.find(:first, :conditions=>{:name => 'Feature request'})
  story_trackers.each{|tracker|
    if copy_from.respond_to? :workflow_rules #redmine 2 master
      tracker.workflow_rules.copy(copy_from)
    else
      tracker.workflows.copy(copy_from)
    end
  }
  copy_from = Tracker.find(:first, :conditions=>{:name => 'Bug'})
  if copy_from.respond_to? :workflow_rules
    task_tracker.save!
    task_tracker.workflow_rules.copy(copy_from)
  else
    task_tracker.workflows.copy(copy_from)
  end

  story_trackers = story_trackers.map{|tracker| tracker.id }
  task_tracker = task_tracker.id
  Backlogs.setting[:story_trackers] = story_trackers
  Backlogs.setting[:task_tracker] = task_tracker

  # Make sure these trackers are enabled in the project
  @project.update_attribute :tracker_ids, (story_trackers << task_tracker)

  # make sure existing stories don't occupy positions that the tests are going to use
  Issue.connection.execute("update issues set position = (position - #{Issue.minimum(:position)}) + #{Issue.maximum(:position)} + 50000")

  Backlogs.setting[:card_spec] = 'Zweckform 3474'
  BacklogsPrintableCards::CardPageLayout.selected.should_not be_nil
end

Given /^no versions or issues exist$/ do
  Issue.destroy_all
  Version.destroy_all
end

Given /^I have selected the (.*) project$/ do |project_id|
  @project = get_project(project_id)
end

Given /^backlogs setting show_burndown_in_sidebar is enabled$/ do
    Backlogs.setting[:show_burndown_in_sidebar] = 'enabled' #app/views/backlogs/view_issues_sidebar.html.erb
end

Given /^I have defined the following sprints?:$/ do |table|
  @project.versions.delete_all
  table.hashes.each do |version|

    #need to get current project defined in the table FIXME: (pa sharing) check this
    version['project_id'] = get_project((version['project_id']||'ecookbook')).id

    ['effective_date', 'sprint_start_date'].each do |date_attr|
      date_string = Chronic.parse(version[date_attr])
      version[date_attr] = date_string.nil? ? nil : date_string.strftime("%Y-%m-%d")
    end

    version['sharing'] = 'none' if version['sharing'].nil?
    status = version.delete('status')

    sprint = RbSprint.create! version
    sprint.update_attribute(:status, 'closed') if status == 'closed'
  end
end

Given /^I have the following issue statuses available:$/ do |table|
  table.hashes.each do |status|
    s = IssueStatus.find(:first, :conditions => ['name = ?', status['name']])
    unless s
      s = IssueStatus.new
      s.name = status['name']
    end

    s.is_closed = status['is_closed'] == '1'
    s.is_default = status['is_default'] == '1'
    s.default_done_ratio = status['default_done_ratio'].to_i unless status['default_done_ratio'].blank?

    s.save!
  end
end

Given /^I have made the following task mutations:$/ do |table|
  table.hashes.each do |mutation|
    mutation.delete_if{|k, v| v.to_s.strip == '' }
    task = RbTask.find_by_subject(mutation.delete('task'))
    task.should_not be_nil

    set_now(mutation.delete('day'), :msg => task.subject, :sprint => current_sprint)
    Time.zone.now.should be >= task.created_on

    task.init_journal(User.current)

    status_name = mutation.delete('status').to_s
    if status_name.blank?
      status = nil
    else
      status = IssueStatus.find(:first, :conditions => ['name = ?', status_name])
      raise "No such status '#{status_name}'" unless status
      status = status.id
    end

    remaining = mutation.delete('remaining')

    task.remaining_hours = remaining.to_f unless remaining.blank?
    task.status_id = status if status
    task.save!.should be_true

    mutation.should == {}
  end
end

Given /^I have deleted all existing issues from all projects$/ do
  Issue.delete_all
end

Given /^I have deleted all existing issues$/ do
  @project.issues.delete_all
end

Given /^I have defined the following stories in the product backlog:$/ do |table|
  table.hashes.each do |story|
    if story['project_id']
      project = get_project(story.delete('project_id'))
    else
      project = @project
    end
    params = initialize_story_params project.id
    params['subject'] = story.delete('subject').strip
    params['story_points'] = story.delete('points').to_i if story['points'].to_s != ''
    params['release_id'] = RbRelease.find_by_name(story['release']).id if story['release'].to_s.strip != ''
    story.delete('release') unless story['release'].nil?

    story.should == {}

    # NOTE: We're bypassing the controller here because we're just
    # setting up the database for the actual tests. The actual tests,
    # however, should NOT bypass the controller
    RbStory.create_and_position(params).move_to_bottom
  end
end

Given /^I have defined the following stories in the following sprints?:$/ do |table|
  table.hashes.each do |story|
    sprint = RbSprint.find_by_name(story.delete('sprint')) #find by name only, please use unique sprint names over projects for tests
    if story['project_id'] # where to put the story into, so we can have a story of project A in a sprint of project B
      project = get_project(story.delete('project_id'))
    else
      project = sprint.project || @project
    end
    sprint.should_not be_nil
    params = initialize_story_params project.id
    params['subject'] = story.delete('subject')
    params['fixed_version_id'] = sprint.id
    params['story_points'] = story.delete('points').to_i if story['points'].to_s != ''
    params['release_id'] = RbRelease.find_by_name(story['release']).id if story['release'].to_s.strip != ''
    story.delete('release') unless story['release'].nil?

    set_now(story.delete('day'), :msg => params['subject'], :sprint => sprint)

    story.should == {}

    # NOTE: We're bypassing the controller here because we're just
    # setting up the database for the actual tests. The actual tests,
    # however, should NOT bypass the controller
    RbStory.create_and_position(params).move_to_bottom
  end
end

Given /^I have defined the following tasks:$/ do |table|
  table.hashes.each do |task|
    story = RbStory.find(:first, :conditions => { :subject => task.delete('story') })
    story.should_not be_nil

    params = initialize_task_params(story.id)
    params['subject'] = task.delete('subject')

    status = task.delete('status')
    params['status_id'] = IssueStatus.find(:first, :conditions => ['name = ?', status]).id unless status.blank?

    hours = task.delete('estimate')
    params['estimated_hours'] = hours.to_f unless hours.blank?
    params['remaining_hours'] = hours.to_f unless hours.blank?

    at = task.delete('when').to_s
    if at =~ /^0-9+/
      set_now(at, :sprint => story.fixed_version, :msg => params['subject'])
    else
      set_now(at, :msg => params['subject'])
    end
    Time.zone.now.should be >= story.created_on

    task.should == {}

    # NOTE: We're bypassing the controller here because we're just
    # setting up the database for the actual tests. The actual tests,
    # however, should NOT bypass the controller
    task = RbTask.create_with_relationships(params, @user.id, story.project.id)
    task.parent_issue_id = story.id # workaround racktest driver weirdness: user is not member of subprojects. phantomjs driver works as expected, though.
    task.save! # workaround racktest driver weirdness
    task
  end
end

Given /^I have defined the following impediments:$/ do |table|
  # sharing: an impediment can block more than on issues, each from different projects, when
  # cross_project_issue_relations is enabled. This is tested not here but using javascript tests.
  table.hashes.each do |impediment|
    sprint = RbSprint.find(:first, :conditions => { :name => impediment.delete('sprint') })
    blocks = RbStory.find(:first, :conditions => ['subject in (?)', impediment['blocks'].split(', ')])
    params = initialize_impediment_params(:project_id => blocks.project_id, :fixed_version_id => sprint.id)
    params['subject'] = impediment.delete('subject')
    params['blocks']  = RbStory.find(:all, :conditions => ['subject in (?)', impediment.delete('blocks').split(', ')]).map{ |s| s.id }.join(',')
    impediment.should == {}

    # NOTE: We're bypassing the controller here because we're just
    # setting up the database for the actual tests. The actual tests,
    # however, should NOT bypass the controller
    RbTask.create_with_relationships(params, @user.id, blocks.project_id, true).should_not be_nil
  end

end

Given /^I am viewing the issues list$/ do
  visit url_for(:controller => 'issues', :action=>'index', :project_id => @project, :only_path=>true)
  verify_request_status(200)
end

Given /^I am viewing the issues sidebar$/ do
  visit url_for(:controller => 'rb_hooks_render', :action=>'view_issues_sidebar', :project_id => @project, :only_path=>true)
  verify_request_status(200)
end

Given /^I am viewing the issues sidebar for (.+)$/ do |name|
  visit url_for(:controller => 'rb_hooks_render',
                :action=>'view_issues_sidebar',
                :project_id => @project,
                :sprint_id => RbSprint.find_by_name(name).id,
                :only_path => true)
  verify_request_status(200)
end

Given /^I am viewing the issue named "([^"]*)"$/ do |name|
  issue = Issue.find_by_subject(name)
  visit url_for(:controller => 'issues', :action=>'show', :id => issue.id, :project_id => @project, :only_path=>true)
  verify_request_status(200)
end

Given /^I have selected card label stock (.+)$/ do |stock|
  Backlogs.setting[:card_spec] = stock
  BacklogsPrintableCards::CardPageLayout.selected.should_not be_nil
end

Given /^I have set my API access key$/ do
  Setting.rest_api_enabled = '1'
  @user.reload
  @user.api_key.should_not be_nil
  @api_key = @user.api_key
end

Given /^I have guessed an API access key$/ do
  Setting.rest_api_enabled = '1'
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
  Backlogs.setting[:wiki_template] = Wiki.titleize(title)
end

Given /^there are no stories in the project$/ do
  @project.issues.delete_all
end

Given /^show me the task hours$/ do
  header = ['task', 'hours']
  data = Issue.find(:all, :conditions => ['tracker_id = ? and fixed_version_id = ?', RbTask.tracker, current_sprint.id]).collect{|t| [t.subject, t.remaining_hours.inspect]}
  show_table("Task hours", header, data)
end

Given /^I have changed the sprint start date to (.*)$/ do |date|
  case date
    when 'today'
      date = Time.zone.today
    when 'tomorrow'
      date = (Time.zone.today + 1)
    else
      date = Time.zone.parse(date).to_date
  end
  current_sprint.sprint_start_date = date
  current_sprint(:keep).save!
end

Given /^I have configured backlogs plugin to include Saturday and Sunday in burndown$/ do
  Backlogs.setting[:include_sat_and_sun] = true
end

Given /^timelog from taskboard has been enabled$/ do
  Backlogs.setting[:timelog_from_taskboard] = 'enabled'
end

Given /^I am a team member of the project and allowed to update remaining hours$/ do
  role = Role.find(:first, :conditions => "name='Manager'")
  role.permissions << :view_master_backlog
  role.permissions << :view_releases
  role.permissions << :view_taskboards
  role.permissions << :create_tasks
  role.permissions << :update_tasks
  role.permissions << :update_remaining_hours
  role.save!
  login_as_team_member
end

Given /^I am logging time for task (.+)$/ do |subject|
  issue = Issue.find_by_subject(subject)
  visit "/issues/#{issue.id}/time_entries"
  click_link('Log time')
  verify_request_status(200)
end

Given /^I am viewing log time for the (.*) project$/ do |project_id|
  visit "/projects/#{project_id}/time_entries"
  click_link('Log time')
  verify_request_status(200)
end

Given /^I set the hours spent to (\d+)$/ do |arg1|
  fill_in 'time_entry[hours]', :with => arg1
end

Given /^I set the remaining_hours to (\d+)$/ do |arg1|
  fill_in 'remaining_hours', :with => arg1
end

Given /^I am duplicating (.+) to (.+) for (.+)$/ do |story_old, story_new, sprint_name|
  issue = Issue.find_by_subject(story_old)
  visit "/projects/#{@project.id}/issues/#{issue.id}/copy"
  verify_request_status(200)
  fill_in 'issue_subject', :with => story_new
  page.select(sprint_name, :from => "issue_fixed_version_id")
end

Given /^I choose to copy (none|open|all) tasks$/ do |copy_option|
  if copy_option == "none"
    choose('copy_tasks_none')
  elsif copy_option == "open"
    field_id = page.find(:xpath, '//input[starts-with(@id,"copy_tasks_open")]')['id']
    choose(field_id)
  else
    field_id = page.find(:xpath, '//input[starts-with(@id,"copy_tasks_all")]')['id']
    choose(field_id)
  end
end

Given /^I have defined the following projects:$/ do |table|
  table.hashes.each do |project|
    name = project.delete('name')
    project.should == {}
    pr = Project.create! :identifier => name, :name => name
  end
end

Given /^the (.*) project is subproject of the (.*) project$/ do |arg1, arg2|
  sub = Project.find(arg1)
  parent = Project.find(arg2)
  sub.set_parent! parent
end

Given /^sharing is (.*)enabled$/ do |neg|
  Backlogs.setting[:sharing_enabled] = !!(neg=='')
end

Given /^default sharing for new sprints is (.+)$/ do |sharing|
  Backlogs.setting[:sharing_new_sprint_sharingmode] = sharing
end

Given /^the project selected not to include subprojects in the product backlog$/ do
  settings = @project.rb_project_settings
  settings.show_stories_from_subprojects = false
  settings.save
end

Given /cross_project_issue_relations is (enabled|disabled)/ do | enabled |
  Setting[:cross_project_issue_relations] = enabled=='enabled'?1:0
end

Given /^I have defined the following releases:$/ do |table|
  RbRelease.delete_all
  table.hashes.each do |release|
    release['project_id'] = get_project((release.delete('project')||'ecookbook')).id
    RbRelease.create! release
  end
end

Given /^I view the release page$/ do
  visit url_for(:controller => :projects, :action => :show, :id => @project, :only_path => true)
  click_link("Releases")
end

Given /^Story closes when all Tasks are closed$/ do
  Backlogs.setting[:story_follow_task_status] = 'close'
  status = IssueStatus.find_by_name('Closed')
  Backlogs.setting[:story_close_status_id] = status.id
end

Given /^Story states loosely follow Task states$/ do
  Backlogs.setting[:story_follow_task_status] = 'loose'
  Backlogs.setting[:story_close_status_id] = '0'
  Setting.issue_done_ratio = 'issue_status' #auto done_ratio for issues. issue_field is not supported (yet)
end

Given /^Issue done_ratio is determined by the issue field$/ do
  Setting.issue_done_ratio = 'issue_field'
end

Given(/^I request the csv format for release "(.*?)"$/) do |arg1|
  r = RbRelease.where(:name => arg1).first
  r.should_not be_nil
  visit url_for(:controller => :rb_releases, :action => :show, :format => :csv, :release_id => r.id, :only_path => true)
end
