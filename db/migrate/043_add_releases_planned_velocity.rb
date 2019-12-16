class AddReleasesPlannedVelocity < (ActiveRecord::VERSION::MAJOR >= 5) ? ActiveRecord::Migration["#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}"] : ActiveRecord::Migration
  def self.up
    add_column :releases, :planned_velocity, :float
  end

  def self.down
    remove_columns :releases, :planned_velocity
  end
end
