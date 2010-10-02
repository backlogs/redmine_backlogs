class FixStatusPositions < ActiveRecord::Migration
  def self.up
    IssueStatus.find(:all).
                each_with_index{|s,i| s.position = i + 1; s.save! }
  end

  def self.down
    raise ActiveRecord::IrreversibleMigration
  end
end
