class ChangeIssuePositionColumn < (ActiveRecord::VERSION::MAJOR >= 5) ? ActiveRecord::Migration["#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}"] : ActiveRecord::Migration
  def self.up
    change_column :issues, :position, :integer, :null => true, :default => nil
  end

  def self.down
    puts "Can't disable null positions"
    # change_column :issues, :position, :integer, :null => false
  end
end
