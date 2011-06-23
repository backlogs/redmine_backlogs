class RemoveTaskPosition < ActiveRecord::Migration
  def self.up
    if Task.tracker
      ActiveRecord::Base.transaction do
        # this intentionally loads tasks as stories so we can issue
        # remove_from_list, which does more than just nilling the
        # position
        Story.find(:all, :conditions => "tracker_id = #{Task.tracker}").each do |t|
          t.remove_from_list
        end
      end
    end
  end

  def self.down
    raise ActiveRecord::IrreversibleMigration
  end
end
