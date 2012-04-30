class FlattenStoryPositions < ActiveRecord::Migration
  def self.up
    # Rails doesn't support temp tables, mysql doesn't support update
    # from same-table subselect
    create_table :backlogs_tmp_issue_position do |t|
      t.column :id, :integer, :null => false
      t.column :position, :integer, :null => false
    end

    execute "INSERT INTO backlogs_tmp_issue_position
             SELECT story.id, COUNT(*) + 1
             FROM issues story
             JOIN issues pred ON
               (pred.project_id < story.project_id)
               OR
               (pred.project_id = story.project_id AND pred.fixed_version_id < story.fixed_version_id)
               OR
               (pred.project_id = story.project_id AND pred.fixed_version_id = story.fixed_version_id AND pred.position < story.position)
             GROUP BY story.id"

    execute "UPDATE issues SET position = (SELECT position FROM backlogs_tmp_issue_position WHERE backlogs_tmp_issue_position.id = issues.id)"

    drop_table :backlogs_tmp_issue_position
  end

  def self.down
    raise ActiveRecord::IrreversibleMigration
  end
end
