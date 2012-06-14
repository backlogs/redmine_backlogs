
#  sleep is a BAD THING(tm)
# have_css does not work?
#  page.should have_css("#story_#{story.id}.saving") #wait for throbber to appear
#  page.should_not have_css("#story_#{story.id}.saving") #wait for throbber to disappear
#wait until does not work?
#  wait_until { page.find(:css, "#story_#{story.id}.saving") }
#  wait_until { !page.find(:css, "#story_#{story.id}.saving") }
#
#check on the ajax request count of jQuery
#raise Capybara::TimeoutError after some time (default 5s, here 15s, set in support/setup.rb).
def wait_for_ajax
  wait_until { 
    page.evaluate_script('RB.$.active') == 0 #jQuery.ajax.active in the next release
  }
end

# on the master backlog page drag a story
# Params:
#   story_name: subject of the dragged story
#   source_sprint: name|nil (optional) name of the sprint where to drag from
#   target_sprint_name: name of the sprint the story should be dragged into
#   before_story_name: name|nil (optional) of the story in the target sprint where to position the source
def drag_story(story_name, source_sprint, target_sprint_name, before_story_name)
  @last_drag_and_drop = {}
  if source_sprint
    story = RbStory.find(:first, :conditions => {
      :fixed_version_id => RbSprint.find(:first, :conditions => {:name => source_sprint.strip }),
      :subject => story_name.strip})
  else
    story = RbStory.find(:first, :conditions => { :subject => story_name.strip})
  end
  story.should_not be_nil
  @last_drag_and_drop[:version_id_before] = story.fixed_version_id
  @last_drag_and_drop[:position_before] = story.position
  element = page.find(:css, "#story_#{story.id}")

  target_sprint_name.strip!
  if target_sprint_name == 'product-backlog'
    target = page.find(:css, "#stories-for-product-backlog")
  else
    sprint_id = sprint_id_from_name(target_sprint_name)
    target = page.find(:css, "#stories-for-#{sprint_id}")
  end
  target.should_not be_nil

  element.drag_to(target)
  if before_story_name
    before = RbStory.find(:first, :conditions => {:subject => before_story_name.strip})
    before.should_not be_nil
    element.drag_to(page.find(:css, "#story_#{before.id}"))
  end

  wait_for_ajax
  story.reload
  return story
end


def taskboard_states_setup
  @taskboard_setup = {:states=>{}, :stories=>{}}
  index = 1
  page.all(:css, "#taskboard #board_header td").each{|cell|
    @taskboard_setup[:states][cell.text] = index
    index += 1
  }
end

def taskboard_check_task(task, story, state)
  taskboard_states_setup unless @taskboard_setup
  task_id = RbTask.find(:first, :conditions => {:subject => task}).id
  story_id = RbStory.find(:first, :conditions => {:subject => story}).id
  n = @taskboard_setup[:states][state]
  page.should have_css("#taskboard #swimlane-#{story_id} td:nth-child(#{n}) div#issue_#{task_id}")
end

def taskboard_check_impediment(impediment, state)
  taskboard_states_setup unless @taskboard_setup
  task = Issue.find_by_subject(impediment)
  n = @taskboard_setup[:states][state]
  page.should have_css("#impediments td:nth-child(#{n}) div#issue_#{task.id}")
end

def drag_task(task, state, story)
  taskboard_states_setup unless @taskboard_setup
  task = RbTask.find(:first, :conditions => {:subject => task})
  story = RbStory.find(:first, :conditions => {:subject => story})
  source = page.find(:css, "#taskboard #issue_#{task.id}")
  n = @taskboard_setup[:states][state]
  target = page.find(:css, "#taskboard #swimlane-#{story.id} td:nth-child(#{n})")
  source.drag_to(target)
  wait_for_ajax

  task.reload
  return task
end
