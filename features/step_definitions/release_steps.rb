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

Then /^show me the release backlog of (.+)$/ do |release_name|
  release = RbRelease.find_by_name(release_name)
  release.should_not be_nil
  RbStory.release_backlog(release).each{|issue|
    puts "  #{issue}"
  }
end

When /^I add story (.+) to release (.+)$/ do |story_name, release_name|
  story = RbStory.find_by_subject(story_name)
  @story_params = {
    :id => story.id,
    :release_id => RbRelease.find_by_name(release_name).id
  }
  page.driver.post(
                      url_for(:controller => :rb_stories,
                              :action => :update,
                              :id => @story_params[:id],
                              :only_path => true),
                      @story_params
                  )
  verify_request_status(200)
  story.reload
end

Then /^story (.+) should belong to release (.+)$/ do |story_name, release_name|
  release = RbRelease.find_by_name(release_name)
  release.should_not be_nil
  story = RbStory.find_by_subject(story_name)
  story.should_not be_nil
  release.issues.exists?(story).should be_true
end

Then /^story (.+) should not belong to any release$/ do |story_name|
  story = RbStory.find_by_subject(story_name)
  story.should_not be_nil
  story.release_id.should be_nil
end

Then /^I should see the release backlog of (.+)$/ do |release|
  release = RbRelease.find_by_name(release)
  release.should_not be_nil
  page.should have_css("#stories-for-release-#{release.id}")
end

Then /^I should see (\d+) stories in the release backlog of (.+)$/ do |count, release|
  release = RbRelease.find_by_name(release)
  release.should_not be_nil
  page.all(:css, "#stories-for-release-#{release.id} .story").length.should == count.to_i
end

Then /^release "([^"]*)" should have (\d+) story points$/ do |release, points|
  release = RbRelease.find_by_name(release)
  release.should_not be_nil
  release.remaining_story_points.should == points.to_f
end
