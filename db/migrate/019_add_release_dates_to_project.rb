class AddReleaseDatesToProject < ActiveRecord::Migration
  def self.up
    add_column :projects, :release_start_date, :date, :null => true
    add_column :projects, :release_end_date, :date, :null => true
  end

  def self.down
    drop_column :projects, :release_start_date
    drop_column :projects, :release_end_date
  end
end
