class AddReleasesPlannedVelocity < ActiveRecord::Migration[5.2]
  def self.up
    add_column :releases, :planned_velocity, :float
  end

  def self.down
    remove_columns :releases, :planned_velocity
  end
end
