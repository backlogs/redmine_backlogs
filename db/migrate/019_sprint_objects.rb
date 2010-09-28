class SprintObjects < ActiveRecord::Migration
  def self.up
    create_table :sprints, :force => true do |t|
      t.column :project_id, :integer, :null => false
      t.column :name, :string, :limit => 30, :null => false
      t.column :description, :string, :default => ""
      t.column :start_date, :date
      t.column :end_date, :date
      t.column :wiki_page_title, :string
      t.column :created_on, :timestamp
      t.column :updated_on, :timestamp
    end

    Sprint.reset_column_information

    add_column :burndown_days, :project_id, :integer, :default => 0, :null => false
    add_column :burndown_days, :sprint_id, :integer, :default => 0, :null => false

    add_column :issues, :sprint_id, :integer

    Version.find(:all).each {|version|
      sprint = Sprint.new
      sprint.project = version.project
      sprint.name = version.name
      sprint.description = version.description
      sprint.start_date = version.sprint_start_date
      sprint.end_date = version.effective_date
      sprint.wiki_page_title = version.wiki_page_title
      sprint.created_on = version.created_on
      sprint.updated_on = version.updated_on
      sprint.save

      BurndownDay.connection.execute("update burndown_days set sprint_id = #{sprint.id.to_i}, project_id = #{sprint.project_id.to_i} where version_id = #{version.id.to_i}")

      Issue.connection.execute("update issues set sprint_id = #{sprint.id.to_i} where fixed_version_id = #{version.id.to_i}")
    }

    remove_column :burndown_days, :version_id
  end

  def self.down
    raise ActiveRecord::IrreversibleMigration
  end
end
