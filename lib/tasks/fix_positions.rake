namespace :redmine do
  namespace :backlogs do
    desc "Remove duplicate positions in the issues table"
    task :fix_positions => :environment do
      RbStory.find(:all, :conditions => ["tracker_id in (?)", RbStory.trackers], :order => "project_id ASC, fixed_version_id ASC, position ASC").each_with_index do |s,i|
        s.position=i+1
        s.save!
      end
    end
  end
end
