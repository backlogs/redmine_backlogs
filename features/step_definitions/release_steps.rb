Given /^I have defined the following releases:$/ do |table|
  @project.releases.delete_all
  table.hashes.each do |release|
    release['project_id'] = get_project((release.delete('project')||'ecookbook')).id
    puts "Creating release #{release['name']}"
    RbRelease.create! release
  end
end

Given /^I view the release page$/ do
  visit url_for(:controller => :projects, :action => :show, :id => @project, :only_path => true)
  click_link("Releases")
end

Then /^show me the releases$/ do
  RbRelease.find(:all).each{|release|
    puts "Release: #{release}"
  }
end

Then /^show me release (.+)$/ do |release_name|
  release = RbRelease.find_by_name(release_name)
  release.should_not be_nil
  puts "Release: #{release}"
  release.issues.each{|issue| puts "  Issue: #{issue}" }
end

When /^I add story (.+) to release (.+)$/ do |story_name, release_name|
  release = RbRelease.find_by_name(release_name)
  release.should_not be_nil
  story = RbStory.find_by_subject(story_name)
  story.should_not be_nil
  release.issues << story
end

Then /^story (.+) should belong to release (.+)$/ do |story_name, release_name|
  release = RbRelease.find_by_name(release_name)
  release.should_not be_nil
  story = RbStory.find_by_subject(story_name)
  story.should_not be_nil
  release.issues.exists?(story).should be_true
end


