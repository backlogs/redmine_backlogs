class AddRbProjectSettings < ActiveRecord::Migration
  def self.up
    create_table :rb_project_settings do |t|
      t.references :project
      t.boolean :show_stories_from_subprojects, :default => true, :null => false
    end
  end

  def self.down
    drop_table :rb_project_settings
  end
end

