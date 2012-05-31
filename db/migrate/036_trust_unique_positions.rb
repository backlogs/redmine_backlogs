require 'benchmark'

class TrustUniquePositions < ActiveRecord::Migration
  def self.up
    # Needed until MySQL undoes the retardation that is http://bugs.mysql.com/bug.php?id=5573
    remove_index :issues, [:position, :position_lock]
    remove_column :issues, :position_lock
  end

  def self.down
    add_column :issues, :position_lock, :integer
    add_index :issues, [:position, :position_lock]
  end
end
