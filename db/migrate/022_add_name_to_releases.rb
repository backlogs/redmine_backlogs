class AddNameToReleases < ActiveRecord::Migration
  def self.up
    add_column :releases, :name, :string, :null => false
  end

  def self.down
    remove_column :releases, :name
  end
end
