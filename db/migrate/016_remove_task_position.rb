class RemoveTaskPosition < ActiveRecord::Migration
  def self.up
    if RbTask.tracker
      ActiveRecord::Base.transaction do
        # this intentionally loads tasks as stories so we can issue
        # remove_from_list, which does more than just nilling the
        # position
        RbStory.find(:all, :conditions => "tracker_id = #{RbTask.tracker}").each do |t|
          t.remove_from_list
        end
      end
    end
  end

  def self.down
    raise ActiveRecord::IrreversibleMigration
  end
end
