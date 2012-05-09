class OrderTasksUsingTree < ActiveRecord::Migration
  def self.up
    last_task = {}
    if RbTask.tracker
      ActiveRecord::Base.transaction do
        RbTask.find(:all, :conditions => ["tracker_id = ?", RbTask.tracker], :order => "project_id ASC, parent_id ASC, position ASC").each do |t|
          begin
            t.move_after last_task[t.parent_id] if last_task[t.parent_id]
          rescue
            # nested tasks break this migrations. Task order not that
            # big a deal, proceed
          end

          last_task[t.parent_id] = t.id
        end
      end
    end
  end

  def self.down
    puts "Reverting irreversible migration"
  end
end
