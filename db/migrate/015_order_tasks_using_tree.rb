class OrderTasksUsingTree < ActiveRecord::Migration
  def self.up
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

    last_task = {}
    if RbTask.tracker
      ActiveRecord::Base.transaction do
        RbTask.find(:all, :conditions => ["tracker_id = ?", RbTask.tracker], :order => "project_id ASC, parent_id ASC, position ASC").each do |t|
          begin
            t.move_after last_task[t.parent_id] if last_task[t.parent_id]
          rescue
            # nested tasks break this migrations. Task order not that
            # big a deal, proceed
          end

          last_task[t.parent_id] = t.id
        end
      end
    end
  end

  def self.down
    puts "Reverting irreversible migration"
  end
end
