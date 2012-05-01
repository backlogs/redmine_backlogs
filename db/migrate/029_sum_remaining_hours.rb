class SumRemainingHours < ActiveRecord::Migration
  def self.up
    unless RbStory.trackers == []
      create_table :backlogs_tmp_story_remaining_hours do |t|
        t.column :tmp_id, :integer, :null => false
        t.column :tmp_root_id, :integer, :null => false
        t.column :tmp_lft, :integer, :null => false
        t.column :tmp_rgt, :integer, :null => false
        t.column :tmp_remaining_hours, :float, :null => false
      end

      # non-leaf stories
      execute "INSERT INTO backlogs_tmp_story_remaining_hours (tmp_id, tmp_root_id, tmp_lft, tmp_rgt, tmp_remaining_hours)
               SELECT id, root_id, lft, rgt, 0
               FROM issues
               WHERE tracker_id IN (#{RbStory.trackers(:type => :string)}) AND lft <> (rgt - 1)"

      # tasks below these stories
      execute "INSERT INTO backlogs_tmp_story_remaining_hours (tmp_id, tmp_root_id, tmp_lft, tmp_rgt, tmp_remaining_hours)
               SELECT issues.id, root_id, lft, rgt, COALESCE(remaining_hours, 0)
               FROM backlogs_tmp_story_remaining_hours
               JOIN issues ON tmp_root_id = root_id AND lft > tmp_lft AND rgt < tmp_rgt"

      # update non-leaf-tasks below non-leaf stories and set their remaining_hours to the sum of their leaf-tasks
      execute "UPDATE issues
               SET remaining_hours = (
                        SELECT SUM(tmp_remaining_hours)
                        FROM backlogs_tmp_story_remaining_hours
                        WHERE root_id = tmp_root_id
                        AND lft < tmp_lft
                        AND rgt > tmp_rgt
                        AND tmp_lft = (tmp_rgt - 1)
               )
               WHERE lft <> (rgt - 1) AND id IN (SELECT tmp_id FROM backlogs_tmp_story_remaining_hours)"

      drop_table :backlogs_tmp_story_remaining_hours
    end
  end

  def self.down
    #pass
  end
end
