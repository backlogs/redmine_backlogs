class ChangeIssuePositionColumn < (Rails.version < 5.1) ? ActiveRecord::Migration : ActiveRecord::Migration[4.2]
  def self.up
    change_column :issues, :position, :integer, :null => true, :default => nil
  end

  def self.down
    puts "Can't disable null positions"
    # change_column :issues, :position, :integer, :null => false
  end
end
