class AddIndexOnIssuesPosition < (ActiveRecord::VERSION::MAJOR >= 5) ? ActiveRecord::Migration["#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}"] : ActiveRecord::Migration
  def self.up
    add_index :issues, :position 
  end

  def self.down
    remove_index :issues, :position 
  end
end
