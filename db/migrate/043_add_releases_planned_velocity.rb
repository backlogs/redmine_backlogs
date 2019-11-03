class AddReleasesPlannedVelocity < (Rails.version < 5.1) ? ActiveRecord::Migration : ActiveRecord::Migration[4.2]
  def self.up
    add_column :releases, :planned_velocity, :float
  end

  def self.down
    remove_columns :releases, :planned_velocity
  end
end
