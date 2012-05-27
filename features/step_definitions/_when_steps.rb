require 'pp'

When /^I create the impediment$/ do
  page.driver.post(
                      url_for(:controller => :rb_impediments,
                              :action => :create,
                              :only_path => true),
                      @impediment_params
                  )
end

When /^I create the story$/ do
  page.driver.post(
                      url_for(:controller => :rb_stories,
                              :action => :create,
                              :only_path => true),
                      @story_params
                  )
end

When /^I create the task$/ do
  page.driver.post(
                      url_for(:controller => :rb_tasks,
                              :action => :create,
                              :only_path => true),
                      @task_params
                  )
end

When /^I create the sprint$/ do
  page.driver.post(
                      url_for(:controller => :rb_sprints,
                              :action => :create,
                              :only_path => true),
                      @sprint_params
                  )
end

When /^I move the story named (.+) below (.+)$/ do |story_subject, prev_subject|
  story = RbStory.find(:first, :conditions => ["subject=?", story_subject])
  prev  = RbStory.find(:first, :conditions => ["subject=?", prev_subject])
  
  attributes = story.attributes
  attributes[:prev]             = prev.id
  attributes[:fixed_version_id] = prev.fixed_version_id

  page.driver.post(
                      url_for(:controller => 'rb_stories',
                              :action => "update",
                              :id => story.id,
                              :only_path => true),
                      attributes.merge({ "_method" => "put" })
                  )
end

When /^I move the story named (.+) (up|down) to the (\d+)(?:st|nd|rd|th) position of the sprint named (.+)$/ do |story_subject, direction, position, sprint_name|
  position = position.to_i
  story = RbStory.find_by_subject(story_subject)
  sprint = RbSprint.find_by_name(sprint_name)
  story.fixed_version = sprint
  
  attributes = story.attributes
  attributes[:prev] = story_before(position, sprint.project, sprint).to_s

  # TODO: why do we need 'direction'?

  page.driver.post(
                      url_for(:controller => 'rb_stories',
                              :action => "update",
                              :id => story.id,
                              :only_path => true),
                      attributes.merge({ "_method" => "put" })
                  )
  verify_request_status(200)
end

When /^I move the (\d+)(?:st|nd|rd|th) story to the (\d+|last)(?:st|nd|rd|th)? position$/ do |old_pos, new_pos|
  @story_ids = page.all(:css, "#product_backlog_container .stories .story .id .v").collect{|s| s.text}

  story_id = @story_ids.delete_at(old_pos.to_i-1)
  story_id.should_not == nil

  new_pos = new_pos.to_i unless new_pos == 'last'
  case new_pos
    when 'last'
      prev = @story_ids.last
    when 1
      prev = ''
    else
      prev = @story_ids[new_pos - 2]
  end

  page.driver.post( 
                      url_for(:controller => :rb_stories,
                              :action => :update,
                              :id => story_id,
                              :only_path => true),
                      {:prev => prev, :project_id => @project.id, "_method" => "put"}
                  )
  verify_request_status(200)

  @story = RbStory.find(story_id.to_i)
end

When /^I request the server_variables resource$/ do
  visit url_for(:controller => :rb_server_variables, :action => :project, :project_id => @project.id, :format => 'js', :only_path => true)
end

When /^I update the impediment$/ do
  page.driver.post( 
                      url_for(:controller => :rb_impediments,
                              :action => :update,
                              :id => @impediment_params['id'],
                              :only_path => true),
                      @impediment_params
                  )
end

When /^I update the sprint$/ do
  page.driver.post(
                      url_for(:controller => 'rb_sprints',
                              :action => "update",
                              :sprint_id => @sprint_params['id'],
                              :only_path => true),
                      @sprint_params.merge({ "_method" => "put" })
                  )
end

When /^I update the story$/ do
  page.driver.post(
                      url_for(:controller => :rb_stories,
                              :action => :update,
                              :id => @story_params[:id],
                              :only_path => true),
                      @story_params #.merge({ "_method" => "put" })
                  )
  @story.reload
end

When /^I update the task$/ do
  page.driver.post(
                      url_for(:controller => :rb_tasks,
                              :action => :update,
                              :id => @task_params[:id],
                              :only_path => true),
                      @task_params.merge({ "_method" => "put" })
                  )
end

Given /^I visit the scrum statistics page$/ do
  visit url_for(:controller => 'rb_all_projects', :action => 'statistics', :only_path => true)
end

When /^I try to download the calendar feed$/ do
  visit url_for({ :key => @api_key, :controller => 'rb_calendars', :action => 'ical', :project_id => @project, :format => 'xml', :only_path => true})
end

When /^I view the master backlog$/ do
  visit url_for(:controller => :projects, :action => :show, :id => @project, :only_path => true)
  click_link("Backlogs")
end

When /^I view the stories of (.+) in the issues tab/ do |sprint_name|
  sprint = RbSprint.find(:first, :conditions => ["name=?", sprint_name])
  visit url_for(:controller => :rb_queries, :action => :show, :project_id => sprint.project_id, :sprint_id => sprint.id, :only_path => true)
end

When /^I view the stories in the issues tab/ do
  visit url_for(:controller => :rb_queries, :action => :show, :project_id=> @project.id, :only_path => true)
end

When /^I view the sprint notes$/ do
  visit url_for(:controller => 'rb_wikis', :action => 'show', :sprint_id => @sprint.id, :only_path => true)
end

When /^I edit the sprint notes$/ do
  visit url_for(:controller => 'rb_wikis', :action => 'edit', :sprint_id => @sprint.id, :only_path => true)
end

When /^the browser fetches (.+) updated since (\d+) (\w+) (.+)$/ do |object_type, how_many, period, direction|
  date = eval("#{ how_many }.#{ period }.#{ direction=='from now' ? 'from_now' : 'ago' }")
  date = date.strftime("%B %d, %Y %H:%M:%S") + '.' + (date.to_f % 1 + 0.001).to_s.split('.')[1]
  visit url_for(:controller => 'rb_updated_items', :action => :show, :project_id => @project.id, :only => object_type, :since => date, :only_path => true)
end

When /^I click (create|copy|save)$/ do |command|
  page.find(:xpath, '//input[@name="commit"]').click
end

