require 'benchmark'

class TrustUniquePositions < ActiveRecord::Migration
  def self.up
    change_column :issues, :position, :integer, :null => false

    # Needed until MySQL undoes the retardation that is http://bugs.mysql.com/bug.php?id=5573
    remove_index :issues, [:position, :position_lock]
    remove_column :issues, :position_lock
  end

  def self.down
  end
end
