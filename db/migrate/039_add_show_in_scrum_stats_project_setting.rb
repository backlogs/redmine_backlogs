class AddShowInScrumStatsProjectSetting < (Rails.version < 5.1) ? ActiveRecord::Migration : ActiveRecord::Migration[4.2]
  def self.up
    add_column :rb_project_settings, :show_in_scrum_stats, :boolean, {:default => true, :null => false}
  end

  def self.down
    remove_column :rb_project_settings, :show_in_scrum_stats
  end
end

