require 'rubygems'
require 'timecop'

Given /^I am a product owner of the project$/ do
  role = Role.find(:first, :conditions => "name='Manager'")
  role.permissions << :view_master_backlog
  role.permissions << :create_stories
  role.permissions << :update_stories
  role.permissions << :view_releases
  role.permissions << :create_releases
  role.permissions << :update_releases
  role.permissions << :destroy_releases
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
  role.permissions << :create_sprints
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
  @sprint = RbSprint.find(:first, :conditions => ["name=?", sprint_name])
  visit url_for(:controller => :rb_burndown_charts, :action => :show, :sprint_id => @sprint.id)
  page.driver.response.status.should == 200
end

Given /^I am viewing the taskboard for (.+)$/ do |sprint_name|
  @sprint = RbSprint.find(:first, :conditions => ["name=?", sprint_name])
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
  story = RbStory.find(:first, :conditions => ["subject=?", story_subject])
  @task_params = initialize_task_params(story.id)
end

Given /^I want to create an impediment for (.+)$/ do |sprint_subject|
  sprint = RbSprint.find(:first, :conditions => { :name => sprint_subject })
  @impediment_params = initialize_impediment_params(sprint.id)
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

Given /^the (.*) project has the backlogs plugin enabled$/ do |project_id|
  Rails.cache.clear
  @project = get_project(project_id)

  # Enable the backlogs plugin
  @project.enabled_modules << EnabledModule.new(:name => 'backlogs')

  # Configure the story and task trackers
  story_trackers = Tracker.find(:all).map{|s| "#{s.id}"}
  task_tracker = "#{Tracker.create!(:name => 'Task').id}"
  plugin = Redmine::Plugin.find('redmine_backlogs')
  Setting.plugin_redmine_backlogs = Setting.plugin_redmine_backlogs.merge( {:story_trackers => story_trackers, :task_tracker => task_tracker } )

  # Make sure these trackers are enabled in the project
  @project.update_attributes :tracker_ids => (story_trackers << task_tracker)
end

Given /^the project has the following sprints?:$/ do |table|
  @project.versions.delete_all
  table.hashes.each do |version|
    version['project_id'] = @project.id
    ['effective_date', 'sprint_start_date'].each do |date_attr|
      if version[date_attr] == 'today'
        version[date_attr] = Date.today.strftime("%Y-%m-%d")
      elsif version[date_attr].blank?
        version[date_attr] = nil
      elsif version[date_attr].match(/^[0-9]{4}-[0-9]{2}-[0-9]{2}$/)
        # we're OK as-is
      elsif version[date_attr].match(/^(\d+)\.(year|month|week|day|hour|minute|second)(s?)\.(ago|from_now)$/)
        version[date_attr] = eval(version[date_attr]).strftime("%Y-%m-%d")
      else
        raise "Unexpected date value '#{version[date_attr]}'"
      end
    end

    RbSprint.create! version
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
  days = @sprint.days(:all).collect{|d| d.to_time}

  table.hashes.each_with_index do |mutation, no|
    task = RbTask.find(:first, :conditions => ['subject = ?', mutation.delete('task')])
    task.should_not be_nil
    task.init_journal(User.current)

    status = mutation.delete('status').to_s
    if status.blank?
      status = nil
    else
      status = IssueStatus.find(:first, :conditions => ['name = ?', status])
      raise "No such status '#{status}'" unless status
      status = status.id
    end

    remaining = mutation.delete('remaining')

    mutated = days[mutation.delete('day').to_i - 1]

    mutated.to_date.should be >= task.created_on.to_date

    mutated = task.created_on if (mutated.to_date == task.created_on.to_date)
    mutated += time_offset("#{(no + 1)*10}m")
    Timecop.travel(mutated) do
      task.remaining_hours = remaining.to_f unless remaining.blank?
      task.status_id = status if status
      task.save!
    end

    mutation.should == {}
  end
end

Given /^I have deleted all existing issues$/ do
  @project.issues.delete_all
end

Given /^the project has the following stories in the product backlog:$/ do |table|
  table.hashes.each do |story|
    params = initialize_story_params
    params['subject'] = story.delete('subject')
    params['prev_id'] = story_before(story.delete('position'))

    story.should == {}

    # NOTE: We're bypassing the controller here because we're just
    # setting up the database for the actual tests. The actual tests,
    # however, should NOT bypass the controller
    RbStory.create_and_position params
  end
end

Given /^the project has the following stories in the following sprints:$/ do |table|
  table.hashes.each do |story|
    params = initialize_story_params
    params['subject'] = story.delete('subject')
    sprint = RbSprint.find(:first, :conditions => [ "name=?", story.delete('sprint') ])
    params['fixed_version_id'] = sprint.id
    params['story_points'] = story.delete('points').to_i if story['points'].to_s != ''
    params['prev_id'] = story_before(story.delete('position'))

    day_added = story.delete('day')
    offset = story.delete('offset')
    created_on = nil

    if day_added
      if day_added == ''
        created_on = (sprint.sprint_start_date - 1).to_time
      else
        created_on = sprint.days(:all)[Integer(day_added)-1].to_time + time_offset('1h')
      end
    elsif offset
      created_on = sprint.sprint_start_date.to_time + time_offset(offset)
    end

    story.should == {}

    # NOTE: We're bypassing the controller here because we're just
    # setting up the database for the actual tests. The actual tests,
    # however, should NOT bypass the controller
    if created_on
      Timecop.travel(created_on) do
        RbStory.create_and_position params
      end
    else
      RbStory.create_and_position params
    end
  end
end

Given /^the project has the following tasks:$/ do |table|
  table.hashes.each do |task|
    story = RbStory.find(:first, :conditions => { :subject => task.delete('story') })
    story.should_not be_nil

    params = initialize_task_params(story.id)
    params['subject'] = task.delete('subject')

    offset = time_offset(task.delete('offset'))

    status = task.delete('status')
    params['status_id'] = IssueStatus.find(:first, :conditions => ['name = ?', status]).id unless status.blank?

    hours = task.delete('estimate')
    params['estimated_hours'] = hours.to_f unless hours.blank?
    params['remaining_hours'] = hours.to_f unless hours.blank?

    task.should == {}

    # NOTE: We're bypassing the controller here because we're just
    # setting up the database for the actual tests. The actual tests,
    # however, should NOT bypass the controller
    if offset
      Timecop.travel(story.created_on + offset) do
        RbTask.create_with_relationships(params, @user.id, @project.id)
      end
    else
      RbTask.create_with_relationships(params, @user.id, @project.id)
    end
  end
end

Given /^the project has the following impediments:$/ do |table|
  table.hashes.each do |impediment|
    sprint = RbSprint.find(:first, :conditions => { :name => impediment.delete('sprint') })
    params = initialize_impediment_params(sprint.id)

    params['subject'] = impediment.delete('subject')
    params['blocks']  = RbStory.find(:all, :conditions => ['subject in (?)', impediment.delete('blocks').split(', ')]).map{ |s| s.id }.join(',')

    impediment.should == {}

    # NOTE: We're bypassing the controller here because we're just
    # setting up the database for the actual tests. The actual tests,
    # however, should NOT bypass the controller
    RbTask.create_with_relationships(params, @user.id, @project.id, true).should_not be_nil
  end

end

Given /^I am viewing the issues list$/ do
  visit url_for(:controller => 'issues', :action=>'index', :project_id => @project)
  page.driver.response.status.should == 200
end

Given /^I am viewing the issues sidebar$/ do
  visit url_for(:controller => 'rb_hooks_render', :action=>'view_issues_sidebar', :project_id => @project)
  page.driver.response.status.should == 200
end

Given /^I am viewing the issues sidebar for (.+)$/ do |name|
  visit url_for(:controller => 'rb_hooks_render', :action=>'view_issues_sidebar', :sprint_id => RbSprint.find_by_name(name).id)
  page.driver.response.status.should == 200
end

Given /^I have selected card label stock (.+)$/ do |stock|
  Setting.plugin_redmine_backlogs = Setting.plugin_redmine_backlogs.merge( {:card_spec => stock } )
  BacklogsCards::LabelStock.selected_label.should_not be_nil
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
  Setting.plugin_redmine_backlogs = Setting.plugin_redmine_backlogs.merge({:wiki_template => Wiki.titleize(title)})
end

Given /^there are no stories in the project$/ do
  @project.issues.delete_all
end

Given /^show me the task hours$/ do
  header = ['task', 'hours']
  data = Issue.find(:all, :conditions => ['tracker_id = ? and fixed_version_id = ?', RbTask.tracker, @sprint.id]).collect{|t| [t.subject, t.remaining_hours.inspect]}
  show_table("Task hours", header, data)
end

Given /^I have changed the sprint start date to (.*)$/ do |date|
  case date
    when 'today'
      date = Date.today.to_time
    when 'tomorrow'
      date = (Date.today + 1).to_time
    else
      raise "Unsupported date '#{date}'"
  end
  @sprint.created_on = date
  @sprint.save!
end

Given /^I have configured backlogs plugin to include Saturday and Sunday in burndown$/ do
  Rails.cache.clear
  Setting.plugin_redmine_backlogs = Setting.plugin_redmine_backlogs.merge({:include_sat_and_sun => true})
end
