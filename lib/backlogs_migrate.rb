module Backlogs::Migrate
  def rb_common_migrate_up
    unless ActiveRecord::Base.connection.table_exists?('rb_issue_history')
      create_table :rb_issue_history do |t|
        t.column :issue_id,    :integer, :default => 0,  :null => false
        t.text   :history
      end
      add_index :rb_issue_history, :issue_id, :unique => true
    end

    unless ActiveRecord::Base.connection.table_exists?('rb_sprint_burndown')
      create_table :rb_sprint_burndown do |t|
        t.column :version_id,    :integer, :default => 0,  :null => false
        t.text   :stories
        t.text   :burndown
        t.timestamps
      end
      add_index :rb_sprint_burndown, :version_id, :unique => true
    end
  end

  def rb_common_migrate_down
  end
end
