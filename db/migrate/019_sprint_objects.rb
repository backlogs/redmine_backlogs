class SprintObjects < ActiveRecord::Migration
  def self.up
    create_table :sprints, :force => true do |t|
      t.column :project_id, :integer, :null => false
      t.column :name, :string, :limit => nil, :null => false
      t.column :description, :string, :default => ""
      t.column :start_date, :date, :null => false
      t.column :end_date, :date, :null => false
      t.column :wiki_page_title, :string
      t.column :created_on, :timestamp
      t.column :updated_on, :timestamp
    end

    Sprint.reset_column_information

    add_column :burndown_days, :project_id, :integer, :default => 0, :null => false
    add_column :burndown_days, :sprint_id, :integer, :default => 0, :null => false

    add_column :issues, :sprint_id, :integer

    # remove_column :burndown_days, :version_id --- NOTE: We may have to delay this until 0.4.1
  end

  def self.down
    raise ActiveRecord::IrreversibleMigration
  end
end
