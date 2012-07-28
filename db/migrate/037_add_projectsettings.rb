class AddProjectsettings < ActiveRecord::Migration
  def self.up
    create_table :rb_projectsettings do |t|
      t.references :project
      t.boolean :show_stories_from_subprojects, :default => true, :null => false
    end
  end

  def self.down
    drop_table :rb_projectsettings
  end
end

