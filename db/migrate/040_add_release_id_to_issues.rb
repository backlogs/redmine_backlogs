class AddReleaseIdToIssues < (ActiveRecord::VERSION::MAJOR >= 5) ? ActiveRecord::Migration["#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}"] : ActiveRecord::Migration
  def self.up
    unless ActiveRecord::Base.connection.column_exists?(:issues, :release_id)
      add_column :issues, :release_id, :integer
    end
  end
  
  def self.down
    remove_column :issues, :release_id
  end
end
