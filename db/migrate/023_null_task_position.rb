require 'benchmark'

class NullTaskPosition < ActiveRecord::Migration
  def self.up
    if RbTask.tracker
      execute "update issues set position = null where tracker_id = #{RbTask.tracker}"
    end

    if RbTask.tracker && RbStory.trackers.size > 0
      create_table :backlogs_tmp_set_task_tracker do |t|
        t.column :story_root_id, :integer, :null => false
        t.column :story_lft, :integer, :null => false
        t.column :story_rgt, :integer, :null => false
      end

      execute "insert into backlogs_tmp_set_task_tracker (story_root_id, story_lft, story_rgt)
                select root_id, lft, rgt from issues where tracker_id in (#{RbStory.trackers(:type=>:string)})"

      execute "update issues set tracker_id = #{RbTask.tracker}
              where exists (select 1 from backlogs_tmp_set_task_tracker where root_id = story_root_id and lft > story_lft and rgt < story_rgt)"

      drop_table :backlogs_tmp_set_task_tracker
    end
  end

  def self.down
    puts "Reverting irreversible migration"
  end
end
