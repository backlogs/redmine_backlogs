class AddReleaseMultiview < ActiveRecord::Migration
  def self.up
    create_table :rb_releases_multiview do |t|
      t.column :name, :string, :null => false
      t.text :description
      t.belongs_to :project
      t.text :release_ids
    end
  end

  def self.down
    drop_table :rb_releases_multiview
  end
end
