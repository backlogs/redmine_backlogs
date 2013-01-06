class AddReleaseIdToIssues < ActiveRecord::Migration
  def self.up
    add_column :issues, :release_id, :integer
  end
  
  def self.down
    remove_column :issues, :release_id
  end
end
