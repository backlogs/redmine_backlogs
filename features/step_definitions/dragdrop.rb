
#  sleep is a BAD THING(tm)
#
#check on the ajax request count of jQuery
#raise Capybara::TimeoutError after some time (default 5s, here 15s, set in support/setup.rb).
def wait_for_ajax
  wait_until { 
    #wait until all animations are finished AND all ajax requests are finished.
    page.evaluate_script('RB.$(":animated").length') == 0 && page.evaluate_script('RB.$.active') == 0 #jQuery.ajax.active in the next release
  }
end

# on the master backlog page drag a story
# Params:
#   story_name: subject of the dragged story
#   target_sprint_name: name of the sprint the story should be dragged into or nil for product backlog
#   before_story_name: name|nil (optional) of the story in the target sprint where to position the source
def drag_story(story_name, target_sprint_name, before_story_name)
  @last_drag_and_drop = {}
  story = RbStory.find_by_subject(story_name.strip)
  story.should_not be_nil
  @last_drag_and_drop[:version_id_before] = story.fixed_version_id
  @last_drag_and_drop[:position_before] = story.position
  element = page.find(:css, "#story_#{story.id}")

  sprint_id = target_sprint_name.nil? ? 'product-backlog' : sprint_id_from_name(target_sprint_name.strip)
  target = page.find(:css, "#stories-for-#{sprint_id}")
  target.should_not be_nil

  element.drag_to(target)
  if before_story_name
    before = RbStory.find(:first, :conditions => {:subject => before_story_name.strip})
    before.should_not be_nil
#jquery DnD is weird. sortable will not work with drag_to. this is known. selenium drag_by might work.
    element.drag_to(page.find(:css, "#story_#{before.id}"))
  end

  wait_for_ajax
  story.reload
  return story
end

def get_taskboard_state_index
  taskboard_state_index = {}
  index = 1
  page.all(:css, "#taskboard #board_header td").each{|cell|
    taskboard_state_index[cell.text] = index
    index += 1
  }
  taskboard_state_index
end

def drag_task(task, state, story)
  task = RbTask.find(:first, :conditions => {:subject => task})
  story = RbStory.find(:first, :conditions => {:subject => story})
  source = page.find(:css, "#taskboard #issue_#{task.id}")
  n = get_taskboard_state_index[state]
  target = page.find(:css, "#taskboard #swimlane-#{story.id} td:nth-child(#{n})")
  source.drag_to(target)

  wait_for_ajax
  task.reload
  return task
end
