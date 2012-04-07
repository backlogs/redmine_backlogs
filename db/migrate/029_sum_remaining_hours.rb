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
      execute "insert into backlogs_tmp_story_remaining_hours (tmp_id, tmp_root_id, tmp_lft, tmp_rgt, tmp_remaining_hours)
               select id, root_id, lft, rgt, 0
               from issues
               where tracker_id in (#{RbStory.trackers(:type=>:string)}) and lft <> (rgt - 1)"

      # tasks below these stories
      execute "insert into backlogs_tmp_story_remaining_hours (tmp_id, tmp_root_id, tmp_lft, tmp_rgt, tmp_remaining_hours)
               select issues.id, root_id, lft, rgt, coalesce(remaining_hours, 0)
               from backlogs_tmp_story_remaining_hours
               join issues on tmp_root_id = root_id and lft > tmp_lft and rgt < tmp_rgt"

      # update non-leaf-tasks below non-leaf stories and set their remaining_hours to the sum of their leaf-tasks
      execute "update issues
               set remaining_hours = (
                        select sum(tmp_remaining_hours)
                        from backlogs_tmp_story_remaining_hours
                        where root_id = tmp_root_id and lft < tmp_lft and rgt > tmp_rgt and tmp_lft = (tmp_rgt - 1)
               )
               where lft <> (rgt - 1) and id in (select tmp_id from backlogs_tmp_story_remaining_hours)"

      drop_table :backlogs_tmp_story_remaining_hours
    end
  end

  def self.down
    #pass
  end
end
