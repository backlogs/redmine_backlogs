require 'benchmark'

class UniquePositions < ActiveRecord::Migration
  def self.up
    begin
      execute("drop table if exists _backlogs_tmp_position")
    rescue
    end

    execute("create table _backlogs_tmp_position (issue_id int not null unique, new_position int not null unique)")

    execute("
      insert into _backlogs_tmp_position (issue_id, new_position)
      select id, (
        select count(*)
        from issues pred
        where
        (pred.position is not null and story.position is not null and pred.position < story.position)
        or
        (pred.position is not null and story.position is not null and pred.position = story.position and pred.id < story.id)
        or
        (story.position is null and pred.position is not null)
        or
        (story.position is null and pred.position is null and pred.id < story.id)
      )
      from issues story
    ")

    execute("update issues set position = (select new_position from _backlogs_tmp_position where id = issue_id)")
    execute("drop table _backlogs_tmp_position")

    change_column :issues, :position, :integer, :null => false

    # Needed until MySQL undoes the retardation that is http://bugs.mysql.com/bug.php?id=5573
    add_column :issues, :position_sentinel, :integer, :null=>false, :default => 0

    add_index :issues, [:position, :position_sentinel], :unique => true
  end

  def self.down
    #pass
  end
end
