class AddShowInScrumStatsProjectSetting < (ActiveRecord::VERSION::MAJOR >= 5) ? ActiveRecord::Migration["#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}"] : ActiveRecord::Migration
  def self.up
    add_column :rb_project_settings, :show_in_scrum_stats, :boolean, {:default => true, :null => false}
  end

  def self.down
    remove_column :rb_project_settings, :show_in_scrum_stats
  end
end

