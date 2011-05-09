class FlattenStoryPositions < ActiveRecord::Migration
  def self.up
    # Rails doesn't support temp tables, mysql doesn't support update
    # from same-table subselect

    create_table :backlogs_tmp_issue_position do |t|
      t.column :id, :integer, :null => false
      t.column :position, :integer, :null => false
    end

    execute "insert into backlogs_tmp_issue_position
             select story.id, count(*) + 1
             from issues story
             join issues pred on
               (pred.project_id < story.project_id)
               or
               (pred.project_id = story.project_id and pred.fixed_version_id < story.fixed_version_id)
               or
               (pred.project_id = story.project_id and pred.fixed_version_id = story.fixed_version_id and pred.position < story.position)
             group by story.id"

    execute "update issues set position = (select position from backlogs_tmp_issue_position where backlogs_tmp_issue_position.id = issues.id)"

    drop_table :backlogs_tmp_issue_position
  end

  def self.down
    raise ActiveRecord::IrreversibleMigration
  end
end
