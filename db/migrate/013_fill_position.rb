class FillPosition < ActiveRecord::Migration
  def self.up
    if RbStory.trackers.size != 0
      pos = execute "select project_id, max(position) from issues where tracker_id in (#{RbStory.trackers(:string)}) group by project_id"
      pos.each do |row|
        project_id = row[0].to_i
        position = row[1].to_i

        RbStory.find(:all, :conditions => ["project_id = ? and tracker_id in (#{RbStory.trackers(:string)}) and position is null", project_id], :order => "created_on").each do |story|
          position += 1

          story.position = position
          story.save
        end
      end
    end
  end

  def self.down
    #pass
  end
end
