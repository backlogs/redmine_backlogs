require 'benchmark'

class UniquePositions < ActiveRecord::Migration
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

    RbStory.transaction do
      ids = RbStory.connection.select_values('select id from issues order by position')
      ids.each_with_index{|id, i|
        RbStory.connection.execute("update issues set position = #{i * RbStory.list_spacing} where id = #{id}")
      }
    end

    change_column :issues, :position, :integer, :null => false

    # Needed until MySQL undoes the retardation that is http://bugs.mysql.com/bug.php?id=5573
    add_column :issues, :position_lock, :integer, :null=>false, :default => 0
    add_index :issues, [:position, :position_lock], :unique => true
  end

  def self.down
    remove_index :issues, [:position, :position_lock]
    remove_column :issues, :position_lock
    change_column :issues, :position, :integer, :null => true
  end
end
