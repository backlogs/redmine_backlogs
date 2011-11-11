class AddStoryPositions < ActiveRecord::Migration
  def self.up
    # Rails doesn't support temp tables, mysql doesn't support update
    # from same-table subselect

    unless RbStory.trackers.size == 0
      create_table :backlogs_tmp_issue_position do |t|
        t.column :id, :integer, :null => false
        t.column :position, :integer, :null => false
      end

      execute "insert into backlogs_tmp_issue_position
               select id, max(position) + id from issues
               where position is null and tracker_id in (#{RbStory.trackers(:string)})"

      execute "update issues
               set position = (select position from backlogs_tmp_issue_position where backlogs_tmp_issue_position.id = issues.id)
               where position is null and tracker_id in (#{RbStory.trackers(:string)})"

      drop_table :backlogs_tmp_issue_position
    end
  end

  def self.down
    raise ActiveRecord::IrreversibleMigration
  end
end
