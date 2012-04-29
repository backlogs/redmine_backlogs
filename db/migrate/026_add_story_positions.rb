class AddStoryPositions < ActiveRecord::Migration
  def self.up
    # Rails doesn't support temp tables, mysql doesn't support update
    # from same-table subselect

    unless RbStory.trackers.size == 0
      max = 0
      execute("SELECT MAX(position) FROM issues").each{|row| max = row[0]}

      execute "UPDATE issues
               SET position = #{max} + id
               WHERE position IS NULL AND tracker_id IN (#{RbStory.trackers(:type => :string)})"
    end
  end

  def self.down
    raise ActiveRecord::IrreversibleMigration
  end
end
