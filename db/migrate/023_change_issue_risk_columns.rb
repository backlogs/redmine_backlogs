class ChangeIssueRiskColumns < ActiveRecord::Migration
  def self.up
    add_column :issues, :relative_gain, :integer
    add_column :issues, :relative_penalty, :integer
    add_column :issues, :relative_risk, :integer
  end

  def self.down
    remove_column :issues, :relative_gain  
    remove_column :issues, :relative_penalty
    remove_column :issues, :relative_risk
  end
end
