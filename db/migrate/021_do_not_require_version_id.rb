class DoNotRequireVersionId < ActiveRecord::Migration
  def self.up
    change_column :burndown_days, :version_id, :integer, :null => true
  end

  def self.down
    raise ActiveRecord::IrreversibleMigration
  end
end
