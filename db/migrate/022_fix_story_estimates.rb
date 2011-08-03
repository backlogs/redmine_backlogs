class FixStoryEstimates < ActiveRecord::Migration
  def self.up
    # stupid mysql doesn't support self-referential subselect updates
    create_table :backlogs_tmp_estimated_hours do |t|
      t.column :id, :integer, :null => false
      t.column :estimated_hours, :float, :null => false
    end

    # sum up all leaf issues
    execute "insert into backlogs_tmp_estimated_hours (id, estimated_hours)
             select story.id, sum(tasks.estimated_hours)
             from issues story
             join issues tasks on tasks.root_id = story.root_id and tasks.lft > story.lft and tasks.rgt < story.rgt and tasks.lft = tasks.rgt - 1
             group by story.id"

    # only update non-leaf issues
    execute "update issues
             set estimated_hours = (select estimated_hours from backlogs_tmp_estimated_hours where backlogs_tmp_estimated_hours.id = issues.id)
             where id in (select id from backlogs_tmp_estimated_hours)"

    drop_table :backlogs_tmp_estimated_hours
  end

  def self.down
    raise ActiveRecord::IrreversibleMigration
  end
end
