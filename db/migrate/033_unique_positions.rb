require 'benchmark'

class UniquePositions < ActiveRecord::Migration
  def self.up
    begin
      execute("drop table _backlogs_tmp_position")
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

    remove_index :issues, :position 

    add_column :issues, :unique_position, :integer
    execute "update issues set unique_position = position"
    remove_column :issues, :position

    add_column :issues, :position, :integer
    execute "update issues set position = unique_position"
    remove_column :issues, :unique_position
    change_column :issues, :position, :integer, :null => false

    add_index :issues, :position, :unique => true
  end

  def self.down
    #pass
  end
end
