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

      execute "insert into backlogs_tmp_story_remaining_hours (tmp_id, tmp_root_id, tmp_lft, tmp_rgt, tmp_remaining_hours)
               select id, root_id, lft, rgt, 0
               from issues
               where tracker_id in (#{RbStory.trackers(:string)})"
      execute "update backlogs_tmp_story_remaining_hours
               set tmp_remaining_hours = (
                  select sum(coalesce(remaining_hours, 0))
                  from issues
                  where root_id = tmp_root_id and lft > tmp_lft and rgt < tmp_rgt
               )"
      execute "update issues
               set remaining_hours = (select tmp_remaining_hours from backlogs_tmp_story_remaining_hours where tmp_id = id)
               where id in (select tmp_id from backlogs_tmp_story_remaining_hours)"

      drop_table :backlogs_tmp_story_remaining_hours
    end
  end

  def self.down
    #pass
  end
end
