require 'rubygems'
require 'pp'

Then /^show me the history for (.+)$/ do |subject|
  issue = RbStory.find_by_subject(subject)
  puts "== #{subject} =="
  issue.history.history.each{|h|
    puts h.inspect
  }
  puts "// #{subject} //"
end

Then /^the history for (.+) should be:$/ do |subject, table|
  story = RbStory.find_by_subject(subject)
  history = story.history.filter(current_sprint)
  table.hashes.each_with_index do |metrics, i|
    metrics.each_pair{|k, v|
      "#{i}, #{k}: #{history[i][k.intern]}".should == "#{i}, #{k}: #{v}"
    }
  end
end

Then /^(.+) should be in the (\d+)(?:st|nd|rd|th) position of the sprint named (.+)$/ do |story_subject, position, sprint_name|
  position = position.to_i
  story = RbStory.where(subject: story_subject).joins(:fixed_version).includes(:fixed_version).where(versions: {name: sprint_name}).first
  story.rank.should == position.to_i
end

Then /^I should see (\d+) sprint backlogs$/ do |count|
  sprint_backlogs = page.all(:css, "#sprint_backlogs_container .sprint", :visible => true)
  sprint_backlogs.length.should == count.to_i
end

Then /^I should see the burndown chart$/ do
  page.should have_css("#burndown_#{current_sprint.id.to_s}")
end

Then /^I should see the burndown chart of sprint (.+)$/ do |sprint_name|
  sprint = RbSprint.find_by_name(sprint_name)
  page.should have_css("#burndown_#{sprint.id.to_s}")
end

Then /^I should see the Issues page$/ do
  page.should have_css("#query_form")
end

Then /^I should see custom backlog columns on the Issues page$/ do
  page.should have_css("#query_form")
  ['story_points','release','position','velocity_based_estimate','remaining_hours'].each{|c|
    page.should have_xpath("//td[@class='#{c}']")
  }
end

Then /^I should see the taskboard$/ do
  page.should have_css('#taskboard')
end

Then /^I should see the product backlog$/ do
  page.should have_css('#product_backlog_container')
  page.should have_css('#stories-for-product-backlog')
end

Then /^I should see (\d+) stories in the product backlog$/ do |count|
  RbStory.product_backlog(@project).all.length.should == count.to_i
  page.all(:css, "#stories-for-product-backlog .story").length.should == count.to_i
end

Then /^show me the list of sprints$/ do
  header = [['id', 3], ['name', 18], ['sprint_start_date', 18], ['effective_date', 18], ['updated_on', 20]]
  data = RbSprint.open_sprints(@project).collect{|sprint| [sprint.id, sprint.name, sprint.start_date, sprint.effective_date, sprint.updated_on] }

  show_table("Sprints", header, data)
end

Then /^show me the list of shared sprints$/ do
  header = [['id', 3], ['name', 18], ['project id', 5], ['sprint_start_date', 18], ['effective_date', 18], ['updated_on', 20]]
  sprints = @project.shared_versions.scoped(:conditions => {:status => ['open', 'locked']}, :order => 'sprint_start_date ASC, effective_date ASC').collect{|v| v.becomes(RbSprint) } 
  data = sprints.collect{|sprint| [sprint.id, sprint.name, sprint.project_id, sprint.start_date, sprint.effective_date, sprint.updated_on] }

  show_table("Sprints", header, data)
end

Then /^the sprint "([^"]*)" should not be shared$/ do |sprint|
  sprint = RbSprint.find_by_name(sprint)
  sprint.sharing.should == "none"
end

Then /^the sprint "([^"]*)" should be shared by (.+)$/ do |sprint, sharing|
  sprint = RbSprint.find_by_name(sprint)
  sprint.sharing.should == sharing
end

Then /^show me the list of issues( on )?(all )?(project)?s?(.*)?$/ do |on, all, project, name|
  query = RbStory,order("position ASC")
  if all.to_s.strip == 'all'
    #
  elsif name.to_s != ''
    query = query.where(project_id: Project.find_by_name(name).id)
  else
    query = query.where(project_id: @project.id)
  end

  header = [['id', 5], ['tracker', 10], ['created', 20], ['position', 8], ['rank', 8], ['status', 12], ['subject', 30], ['sprint', 20], ['remaining', 10]]
  data = query.collect {|story|
    [story.id, story.tracker.name, story.created_on, story.position, story.rank, story.status.name, story.subject, story.fixed_version_id.nil? ? 'Product Backlog' : story.fixed_version.name, story.remaining_hours]
  }

  show_table("Stories", header, data)
end

Then /^show me the sprint impediments$/ do
  puts "Impediments for #{current_sprint.name}: #{current_sprint(:keep).impediments.collect{|i| i.subject}.inspect}"
end

Then /^show me the projects$/ do
  show_projects
end

Then /^show me the response body$/ do
  puts page.driver.body
end

Then /^(.+) should be the higher item of (.+)$/ do |higher_subject, lower_subject|
  higher = RbStory.find_by_subject(higher_subject)
  lower = RbStory.find_by_subject(lower_subject)
  higher.should_not be_nil
  lower.should_not be_nil
  lower.higher_item.should_not be_nil
  higher.lower_item.should_not be_nil

  higher.position.should < lower.position
  lower.higher_item.id.should == higher.id
  higher.lower_item.id.should == lower.id
end

Then /^the request should complete successfully$/ do
  verify_request_status(200)
end

Then /^the request should fail$/ do
  verify_request_status(401)
end

Then /^calendar feed download should (succeed|fail)$/ do |status|
  (status == 'succeed').should == page.body.include?('BEGIN:VCALENDAR')
end

Then /^the (\d+)(?:st|nd|rd|th) story in (.+) should be (.+)$/ do |position, backlog, subject|
  sprint = (backlog == 'the product backlog' ? nil : Version.find_by_name(backlog))
  story = RbStory.backlog_scope(:project => @project, :sprint => sprint).find_by_rank(position.to_i)

  story.should_not be_nil
  story.subject.should == subject
end

Then /^the (\d+)(?:st|nd|rd|th) story in (.+) should have the tracker (.+)$/ do |position, backlog, tracker|
  sprint = (backlog == 'the product backlog' ? nil : Version.find_by_name(backlog))
  story = RbStory.backlog_scope(:project => @project, :sprint => sprint).find_by_rank(position.to_i)

  t = get_tracker(tracker)
  
  story.should_not be_nil
  story.tracker.should == t
end

Then /^the (\d+)(?:st|nd|rd|th) task for (.+) should be (.+)$/ do |position, story_subject, task_subject|
  story = RbStory.where(subject: story_subject).first
  story.should_not be_nil
  story.children.length.should be >= position.to_i
  story.children[position.to_i - 1].subject.should == task_subject
end

Then /^the (\d+)(?:st|nd|rd|th) task for (.+) is assigned to (.+)$/ do |position, story_subject, task_assigned_to|
  story = RbStory.where(subject: story_subject).first
  story.should_not be_nil
  story.children.length.should be >= position.to_i
  story.children[position.to_i - 1].assigned_to.should == User.where(login: task_assigned_to).first
end

Then /^the server should return an update error$/ do
  verify_request_status(400)
end

Then /^the server should return (\d+) updated (.+)$/ do |count, object_type|
  page.all("##{object_type.pluralize} .#{object_type.singularize}").length.should == count.to_i
end

Then /^Story "([^"]*)" should be updated$/ do |story|
  story_id = RbStory.find_by_subject(story).id
  page.should have_css("#story_#{story_id}")
end
Then /^Story "([^"]*)" should not be updated$/ do |story|
  story_id = RbStory.find_by_subject(story).id
  page.should_not have_css("#story_#{story_id}")
end

Then /^The last_update information should be near (.+)$/ do |t|
  lu = page.find(:css, "#last_updated").text()
  lu.start_with?(t).should be true #coarse. hmm.
end

Then /^the sprint named (.+) should have (\d+) impediments? named (.+)$/ do |sprint_name, count, impediment_subject|
  sprint = RbSprint.where(name: sprint_name).all
  sprint.length.should == 1
  sprint = sprint.first

  impediments = sprint.impediments
  impediments.size.should == count.to_i

  subjects = {}
  impediment_subject.split(/(?:\s+and\s+)|(?:\s*,\s*)/).each {|s|
    subjects[s] = 0
  }
  sprint.impediments.each{|i|
    subjects[i.subject].should_not be_nil
    subjects[i.subject] += 1 if subjects[i.subject]
  }
  subjects.values.select{|v| v == 0}.size.should == 0
end

Then /^the sprint should be updated accordingly$/ do
  sprint = RbSprint.find(@sprint_params['id'])
  
  sprint.attributes.each_key do |key|
    unless ['updated_on', 'created_on'].include?(key)
      case
        when sprint[key].nil?
          @sprint_params[key].should be_nil
        when key =~ /_date/
          sprint[key].strftime("%Y-%m-%d").should == @sprint_params[key]
        else
          sprint[key].should == @sprint_params[key]
      end
    end
  end
end

Then /^the sprint "([^"]*)" should be in project "([^"]*)"$/ do |sprint, project|
  project = get_project(project)
  sprint = RbSprint.find_by_name(sprint)
  project.should_not be_nil
  sprint.should_not be_nil
  sprint.project.should == project
end

Then /^the status of the story should be set as (.+)$/ do |status|
  @story.reload
  @story.status.name.downcase.should == status
end

Then /^the story named (.+) should have (\d+) task named (.+)$/ do |story_subject, count, task_subject|
  stories = RbStory.where(subject: story_subject ).all
  stories.length.should == 1

  tasks = stories.first.descendants
  tasks.length.should == 1
  
  tasks.first.subject.should == task_subject
end

Then /^the story should be at the (top|bottom)$/ do |position|
  if position == 'top'
    story_position(@story).should == 1
  else
    story_position(@story).should == @story_ids.length
  end
end

Then /^the story should be at position (.+)$/ do |position|
  story_position(@story).should == position.to_i
end

Then /^the story should have a (.+) of (.+)$/ do |attribute, value|
  @story.reload
  if attribute=="tracker"
    attribute="tracker_id"
    value = Tracker.find_by_name(value).id
  end
  @story[attribute].should == value
end

Then /^the wiki page (.+) should contain (.+)$/ do |title, content|
  title = Wiki.titleize(title)
  page = @project.wiki.find_page(title)
  page.should_not be_nil

  raise "\"#{content}\" not found on page \"#{title}\"" unless page.content.text.match(/#{content}/) 
end

Then /^(issue|task|story) (.+) should have (.+) set to (.+)$/ do |type, subject, attribute, value|
  issue = Issue.find_by_subject(subject)
  issue.send(attribute.intern).should == value.to_i
end

Then /^the sprint burn(down|up) should be:$/ do |direction, table|
  dayno = table.hashes[-1]['day']
  dayno = '0' if dayno == 'start'
  set_now(dayno.to_i + 1, :sprint => @sprint)

  bd = current_sprint(:keep).burndown
  bd.direction = direction
  bd = bd.data

  days = current_sprint(:keep).days

  table.hashes.each do |metrics|
    day = metrics.delete('day')
    day = (day == 'start' ? 0 : day.to_i)
    date = days[day]

    metrics.keys.sort{|a, b| a.to_s <=> b.to_s}.each do |k|
      expected = metrics[k]
      got = bd[k.intern][day]

      # If we get a nil, leave expected alone -- if expected is '' or nil, it'll match, otherwise it's a mismatch anyhow
      expected = got.to_s.match(/\./) ? expected.to_f : expected.to_i unless got.nil?

      "#{date}, #{k}: #{got}".should == "#{date}, #{k}: #{expected}"
    end
  end
end

Then /^show me the sprint burn(.*)$/ do |direction|
  sprint = current_sprint(:keep)
  burndown = sprint.burndown
  burndown.direction = direction

  series = burndown.series(false)
  dates = burndown.days

  tz = RbIssueHistory.burndown_timezone
  ticks = dates.collect{|d| #Copypasta of tick renderer in _burndown.
    tz.local(d.year, d.mon, d.mday)
  }.collect{|t| t.strftime('%a')[0, 1].downcase + ' ' + t.strftime(::I18n.t('date.formats.short')) }

  data = series.collect{|s| burndown.data[s.intern].enum_for(:each_with_index).collect{|d,i| [i*2, d]}}

  puts "== #{sprint.name} =="
  puts dates.inspect
  puts series.inspect
  puts data.inspect
  puts burndown.data.inspect
  puts "// #{sprint.name} //"
  #show_table("Burndown for #{current_sprint(:keep).name} (#{current_sprint(:keep).sprint_start_date} - #{current_sprint(:keep).effective_date})", header, data)
end

Then /^show me the (.+) burndown for story (.+)$/ do |series, subject|
  story = RbStory.find_by_subject(subject)
  show_table("Burndown for story #{subject}, created on #{story.created_on}", ['date', 'hours'], current_sprint.days.zip(story.burndown[series.intern]))
end
Then /^show me the burndown for task (.+)$/ do |subject|
  sprint = task.fixed_version.becomes(RbSprint)

  task = RbTask.find_by_subject(subject)
  show_table("Burndown for #{subject}, created on #{task.created_on}", ['date', 'hours'], sprint.days.zip(task.burndown))
end

Then /^show me the journal for (.+)$/ do |subject|
  columns = []
  data = []
  subject.split(',').each{|s|
    issue = RbStory.find_by_subject(s.strip)
    raise "No issue with subject '#{subject}'" unless issue

    columns = (columns + issue.history.history.collect{|d| d.keys}.flatten).uniq
    data << issue.history.history.collect{|d| d.reject{|k, v| [:origin, :status_id].include?(k)}.merge(:issue => issue.subject)}
    #puts "\n#{issue.subject}:\n  #{issue.history.history.inspect}\n  #{issue.is_story? ? issue.burndown.inspect : ''}\n"
  }
  columns = [:issue, :date] + columns.reject{|c| [:issue, :date].include?(c)}.sort{|a, b| a.to_s <=> b.to_s}
  data.flatten!
  data.sort!{|a, b| "#{a[:date]}:#{a[:issue]}" <=> "#{b[:date]}:#{b[:issue]}"}

  puts "\n"
  puts columns.collect{|c| c.to_s}.join("\t")

  data.each{|mutation|
    puts columns.collect{|c| mutation[c].to_s}.join("\t")
  }
  puts "\n"
end

Then /^show me the story burndown for (.+)$/ do |story|
  story = RbStory.where(subject: story).first
  bd = story.burndown
  header = ['day'] + bd.keys.sort{|a, b| a.to_s <=> b.to_s}
  bd['day'] = current_sprint(:keep).days
  data = bd.transpose.collect{|row| header.collect{|k| row[k]}}
  show_table("Burndown for story #{story.subject}", header.collect{|h| h.to_s}, data)
end

Then /^task (.+) should have a total time spent of (\d+) hours$/ do |subject,value|
  issue = Issue.find_by_subject(subject)
  issue.spent_hours.should == value.to_f
end

Then /^sprint (.+) should contain (.+)$/ do |sprint_name, story_subject|
  story = RbStory.where(:subject => story_subject).joins(:fixed_version).includes(:fixed_version).where(versions: {:name => sprint_name}).first #beware, fixed_version is the relation, Versions the class and versions the table for our sprint. Duh.
  story.should_not be_nil
end

Then /^the story named (.+) should have a task named (.+)$/ do |story_subject, task_subject|
  stories = RbStory.where(:subject => story_subject).all
  stories.length.should == 1

  tasks = RbTask.where(:subject => task_subject, :parent_id => stories.first.id).all
  tasks.length.should == 1
end

Then /^I should see (\d+) stories in the sprint backlog of (.+)$/ do |arg1, arg2|
  sprint_id = sprint_id_from_name(arg2.strip)
  stories = page.all(:css, "#stories-for-#{sprint_id} .story")
  stories.length.should == arg1.to_i
end

Then /^The menu of the sprint backlog of (.*) should (.*)allow to create a new Story in project (.*)$/ do |arg1, neg, arg3|
  sprint_id = sprint_id_from_name(arg1.strip)
  project = get_project(arg3)
  links = page.all(:xpath, "//div[@id='sprint_#{sprint_id}']/..//a[contains(@class,'add_new_story')]")
  found = check_backlog_menu_new_story(links, project)
  found.should == !!(neg=='')
end

Then /^The menu of the product backlog should (.*)allow to create a new Story in project (.+)$/ do |neg, arg3|
  project = get_project(arg3)
  links = page.all(:css, "#product_backlog_container a.add_new_story")
  found = check_backlog_menu_new_story(links, project)
  found.should == !!(neg=='')
end

Then /^I should (.*)see the backlog of Sprint (.+)$/ do |neg, arg1|
  sprint_id = sprint_id_from_name(arg1.strip)
#  page.should_not have_css(:css, "#sprint_#{sprint_id}", :visible => true) if neg != ''
#  page.should have_css(:css, "#sprint_#{sprint_id}", :visible => true) if neg == ''
  begin
    page.find(:css, "#sprint_#{sprint_id}", :visible => true)
    found = true
  rescue
    found = false
  end
  found.should == !!(neg=='')
end

Then /^story (.+?) is unchanged$/ do |story_name|
  story = RbStory.find_by_subject(story_name)
  @last_drag_and_drop.should_not be_nil
  @last_drag_and_drop[:position_before].should == story.position
  @last_drag_and_drop[:version_id_before].should == story.fixed_version_id
end

Then /^story (.+?) is in the product backlog$/ do |story_name|
  story = RbStory.find_by_subject(story_name)
  story.fixed_version_id.should be_nil
end

#taskboard visual checks:
Then /^I should see task (.+) in the row of story (.+) in the state (.+)$/ do |task, story, state|
  task_id = RbTask.find_by_subject(task).id
  story_id = RbStory.find_by_subject(story).id
  n = get_taskboard_state_index[state]
  page.should have_css("#taskboard #swimlane-#{story_id} td:nth-child(#{n}) div#issue_#{task_id}")
end

Then /^task (.+?) should have the status (.+)$/ do |task, state|
  state = IssueStatus.find_by_name(state)
  task = RbTask.find_by_subject(task)
  task.should_not be_nil
  task.status_id.should == state.id
end

Then /^story (.+?) should have the status (.+)$/ do |story, state|
  state = IssueStatus.find_by_name(state)
  story = RbStory.find_by_subject(story)
  story.status_id.should == state.id
end

Then /^I should see impediment (.+) in the state (.+)$/ do |impediment, state|
  task = Issue.find_by_subject(impediment)
  n = get_taskboard_state_index[state]
  page.should have_css("#impediments td:nth-child(#{n}) div#issue_#{task.id}")
end

Then /^impediment (.+) should be created without error$/ do |impediment_name|
  impediment = Issue.find_by_subject(impediment_name)
  impediment.should_not be_nil
  begin
    msg = page.find(:css, "div#msgBox")
    #puts "Got msg box: #{msg.text}" if msg
  rescue
  end
  msg.should be_nil
  page.should have_css("#issue_#{impediment.id}")
end

Then /^I should see a msgbox with "([^"]*)"$/ do |arg1|
  msg = page.find(:css, "div#msgBox")
  msg.text.strip.should == arg1.strip
end

Then /^I should see the mini-burndown-chart in the sidebar$/ do
  page.should have_css("#sidebar .burndown_chart canvas.jqplot-base-canvas")
end

Then /^show me the html content$/ do
  puts page.html
end

Then /^(.+) for (.+) should be (true|false)$/ do |key, project, value|
  project = Project.find(project)
  project.should_not be nil
  setting = project.rb_project_settings.send(key)
  if value=="true" || value === true
    setting.should be true
  else
    setting.should be false
  end
end

#only with phantomjs driver:
Then /^show me a screenshot at (.+)$/ do |arg1|
  page.driver.render(arg1, :full=>true)
end

Then /^dump the database to (.+)$/ do |arg1|
  system("pg_dump redmine_test > #{arg1}")
end

Then /^open the remote inspector$/ do
  page.driver.debug
end

Then /^the error message should say "([^"]*)"$/ do |msg|
  response_msg = page.find(:xpath,"//div[@class='errors']/div")
  response_msg.text.strip.should == msg
end

Then /^the issue should display (\d+) remaining hours$/ do |hours|
  field = page.find(:xpath, "//th[contains(normalize-space(text()),'Remaining')]/following-sibling::td")
  field.text.should == "#{"%.2f" % hours.to_f} hours"
end

Then /^the done ratio for story (.+?) should be (\d+)$/ do |story, ratio|
  story = RbStory.find_by_subject(story)
  story.should_not be_nil
  story.done_ratio.should == ratio.to_i
end

# Low level tests on private methods higher_item_unscoped and lower_item_unscoped, should be rspec tests
Then /^"([^"]*)"\.higher_item_unscoped should be "([^"]*)"$/ do |obj, arg|
  obj = RbStory.find_by_subject(obj)
  if arg == "nil"
    obj.send(:higher_item_unscoped).should be_nil
  else
    arg = RbStory.find_by_subject(arg)
    obj.send(:higher_item_unscoped).should == arg
    arg.send(:lower_item_unscoped).should == obj
  end
end
Then /^"([^"]*)"\.lower_item_unscoped should be "([^"]*)"$/ do |obj, arg|
  obj = RbStory.find_by_subject(obj)
  if arg == "nil"
    obj.send(:lower_item_unscoped).should be_nil
  else
    arg = RbStory.find_by_subject(arg)
    obj.send(:lower_item_unscoped).should == arg
    arg.send(:higher_item_unscoped).should == obj
  end
end

Then(/^release multiview "(.*?)" should contain "(.*?)"$/) do |release_multiview_name, releases|
  m = RbReleaseMultiview.find_by_name(release_multiview_name)
  m.should_not be_nil

  release_names = releases.split(",")
  expected_releases = RbRelease.where(name: release_names).all.map{|r| r.id}
  m.releases.map{|r| r.id}.should == expected_releases
end
