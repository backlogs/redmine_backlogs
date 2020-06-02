class AddShowInScrumStatsProjectSetting < ActiveRecord::Migration[5.2]
  def self.up
    add_column :rb_project_settings, :show_in_scrum_stats, :boolean, {:default => true, :null => false}
  end

  def self.down
    remove_column :rb_project_settings, :show_in_scrum_stats
  end
end

