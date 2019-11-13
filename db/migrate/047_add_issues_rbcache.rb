class AddIssuesRbcache < (Rails.version < 5.1) ? ActiveRecord::Migration : ActiveRecord::Migration[4.2]
  def self.up
    create_table :rb_release_burndown_caches do |t|
      t.column :issue_id, :integer, :null => false
      t.column :value, :text
    end
    add_index :rb_release_burndown_caches, :issue_id
  end

  def self.down
    drop_table :rb_release_burndown_caches
  end
end
