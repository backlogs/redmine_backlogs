#
# load all stories and just save them again
# in order to trigger _before_save hook. This way, remaining_hours get
# recalculated for each story. This fixes probably weird behavior of
# the current day of the burndown graph after upgrading an existing old database
#
namespace :redmine do
  namespace :backlogs do
    desc "Touch all stories so they rebuild the remaining yours from their leaves"
    task :touch_stories => :environment do
      RbStory.where(['tracker_id in (?)', RbStory.trackers]).each{|story|
        puts "Touch #{story.id}"
        story.save!
      }
    end
  end
end
