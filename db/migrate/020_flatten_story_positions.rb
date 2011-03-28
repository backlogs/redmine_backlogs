class FlattenStoryPositions < ActiveRecord::Migration
  def self.up
    # stupid "Attempted to update a stale object" errors

    # this makes sure everything has an unique id that won't conflict
    # with what we're about to do next
    execute "update issues set position = -id"

    Story.find(:all, :order => "project_id ASC, fixed_version_id ASC, position ASC").each_with_index do |s,i|
      execute "update issues set position=#{i+1} where id=#{s.id}"
    end
  end

  def self.down
    raise ActiveRecord::IrreversibleMigration
  end
end
