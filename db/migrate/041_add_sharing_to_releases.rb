class AddSharingToReleases < ActiveRecord::Migration[5.2]
  def self.up
    add_column :releases, :sharing, :string, :default => 'none', :null => false
    add_index :releases, :sharing
  end

  def self.down
    remove_column :releases, :sharing
  end
end
