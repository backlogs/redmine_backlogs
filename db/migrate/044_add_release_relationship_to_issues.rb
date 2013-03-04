class AddReleaseRelationshipToIssues < ActiveRecord::Migration
  def self.up
      add_column :issues, :release_relationship, :string, :default => 'auto', :null => false
  end
  
  def self.down
    remove_column :issues, :release_relationship
  end
end
