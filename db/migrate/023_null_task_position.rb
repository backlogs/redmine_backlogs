require 'benchmark'

class NullTaskPosition < ActiveRecord::Migration
  def self.up
    if RbTask.tracker
      execute "UPDATE issues SET position = NULL WHERE tracker_id = #{RbTask.tracker}"
    end

    if RbTask.tracker && RbStory.trackers.size > 0
      create_table :backlogs_tmp_set_task_tracker do |t|
        t.column :story_root_id, :integer, :null => false
        t.column :story_lft, :integer, :null => false
        t.column :story_rgt, :integer, :null => false
      end

      execute "INSERT INTO backlogs_tmp_set_task_tracker (story_root_id, story_lft, story_rgt)
               SELECT root_id, lft, rgt FROM issues WHERE tracker_id IN (#{RbStory.trackers(:type => :string)})"

      execute "UPDATE issues SET tracker_id = #{RbTask.tracker}
               WHERE exists (SELECT 1 FROM backlogs_tmp_set_task_tracker WHERE root_id = story_root_id AND lft > story_lft AND rgt < story_rgt)"

      drop_table :backlogs_tmp_set_task_tracker
    end
  end

  def self.down
    raise ActiveRecord::IrreversibleMigration
  end
end
