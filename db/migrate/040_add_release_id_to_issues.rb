class AddReleaseIdToIssues < (Rails.version < 5.1) ? ActiveRecord::Migration : ActiveRecord::Migration[4.2]
  def self.up
    unless ActiveRecord::Base.connection.column_exists?(:issues, :release_id)
      add_column :issues, :release_id, :integer
    end
  end
  
  def self.down
    remove_column :issues, :release_id
  end
end
