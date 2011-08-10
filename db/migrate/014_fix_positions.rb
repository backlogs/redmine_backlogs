class FixPositions < ActiveRecord::Migration
  def self.up
    if RbStory.trackers.size != 0
      ActiveRecord::Base.transaction do
        RbStory.find(:all, :conditions => ["tracker_id in (?)", RbStory.trackers], :order => "project_id ASC, fixed_version_id ASC, position ASC").each_with_index do |s,i|
          s.position=i+1
          s.save!
        end
      end
    end
  end

  def self.down
    raise ActiveRecord::IrreversibleMigration
  end
end
