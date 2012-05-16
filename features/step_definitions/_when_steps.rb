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
  story = RbStory.find(:first, :conditions => ["subject=?", story_subject])
  sprint = RbSprint.find(:first, :conditions => ["name=?", sprint_name])
  story.fixed_version = sprint
  
  attributes = story.attributes
  attributes[:prev] = if position == 1
                        ''
                      else
                        stories = RbStory.find(:all, :conditions => ["fixed_version_id=? AND tracker_id IN (?)", sprint.id, RbStory.trackers], :order => "position ASC")
                        raise "You indicated an invalid position (#{position}) in a sprint with #{stories.length} stories" if 0 > position or position > stories.length
                        stories[position - (direction=="up" ? 2 : 1)].id
                      end

  page.driver.post(
                      url_for(:controller => 'rb_stories',
                              :action => "update",
                              :id => story.id,
                              :only_path => true),
                      attributes.merge({ "_method" => "put" })
                  )
end

When /^I move the (\d+)(?:st|nd|rd|th) story to the (\d+|last)(?:st|nd|rd|th)? position$/ do |old_pos, new_pos|
  @story_ids = page.all(:css, "#product_backlog_container .stories .story .id .v")

  story = @story_ids[old_pos.to_i-1]
  story.should_not == nil

  prev = if new_pos.to_i == 1
           nil
         elsif new_pos=='last'
           @story_ids.last
         elsif old_pos.to_i > new_pos.to_i
           @story_ids[new_pos.to_i-2]
         else
           @story_ids[new_pos.to_i-1]
         end

  page.driver.post( 
                      url_for(:controller => :rb_stories,
                              :action => :update,
                              :id => story.text,
                              :only_path => true),
                      {:prev => (prev.nil? ? '' : prev.text), :project_id => @project.id, "_method" => "put"}
                  )

  @story = RbStory.find(story.text.to_i)
end

When /^I request the server_variables resource$/ do
  visit url_for(:controller => :rb_server_variables, :action => :project, :project_id => @project.id, :only_path => true)
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
  visit url_for({ :key => @api_key, :controller => 'rb_calendars', :action => 'ical', :project_id => @project, :format => 'api', :only_path => true})
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

