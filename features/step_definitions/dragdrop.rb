
# on the master backlog page drag a story
# Params:
#   story_name: subject of the dragged story
#   source_sprint: name|nil (optional) name of the sprint where to drag from
#   target_sprint_name: name of the sprint the story should be dragged into
#   before_story_name: name|nil (optional) of the story in the target sprint where to position the source
def drag_story(story_name, source_sprint, target_sprint_name, before_story_name)
  @last_dnd = {}
  if source_sprint
    story = RbStory.find(:first, :conditions => {
      :fixed_version_id => RbSprint.find(:first, :conditions => {:name => source_sprint.strip }),
      :subject => story_name.strip})
  else
    story = RbStory.find(:first, :conditions => { :subject => story_name.strip})
  end
  story.should_not be_nil
  @last_dnd[:story] = story
  @last_dnd[:version_id_before] = story.fixed_version_id
  @last_dnd[:position_before] = story.position
  element = page.find(:css, "#story_#{story.id}")
  @last_dnd[:source_el] = element

  target_sprint_name.strip!
  if target_sprint_name == 'product-backlog'
    target = page.find(:css, "#stories-for-product-backlog")
  else
    sprint = RbSprint.find(:first, :conditions => {:name => target_sprint_name })
    sprint.should_not be_nil
    target = page.find(:css, "#stories-for-#{sprint.id}")
  end
  target.should_not be_nil
  @last_dnd[:target] = target

  element.drag_to(target)
  if before_story_name
    before = RbStory.find(:first, :conditions => {:subject => before_story_name.strip})
    before.should_not be_nil
    element.drag_to(page.find(:css, "#story_#{before.id}"))
  end
  sleep 1 #FIXME (pa sharing) wait for ajax to happen. capybara does not see the change since the dom node is still on the page
  story.reload
  @last_dnd[:version_id_after] = story.fixed_version_id
  @last_dnd[:position_after] = story.position
  return story
end
