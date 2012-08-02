# Sets up the Rails environment for Cucumber
ENV["RAILS_ENV"] = "test"
require File.expand_path(File.dirname(__FILE__) + '/../../config/environment')
require 'cucumber/rails/world'
Cucumber::Rails::World.use_transactional_fixtures = true

if Rails::VERSION::MAJOR >= 3
  require 'rspec/rails/matchers'
  World(RSpec::Rails::Matchers::RoutingMatchers)
end

#Seed the DB
def seed_the_database
  if Rails::VERSION::MAJOR < 3
    fixtures = Fixtures
  else
    fixtures = ActiveRecord::Fixtures
  end
  seed_the_database_with(fixtures)
end

def seed_the_database_with(fixtures)
  fixtures.reset_cache
  fixtures_folder = File.join(Rails.root, 'test', 'fixtures')
  fixtures_files = Dir[File.join(fixtures_folder, '*.yml')].map {|f| File.basename(f, '.yml') }
  fixtures.create_fixtures(fixtures_folder, fixtures_files)
end

seed_the_database

if Cucumber::Rails.const_defined?(:Database)
  # only for recent cucumber-rails
  # do not clean the database between @javascript scenarios
  Cucumber::Rails::Database.javascript_strategy = :transaction
else
  DatabaseCleaner.strategy = nil
  Before do
    seed_the_database
  end
end

# use headless webkit to test javascript ui
require 'capybara/poltergeist'
Capybara.javascript_driver = :poltergeist
Capybara.register_driver :poltergeist do |app|
  Capybara::Poltergeist::Driver.new(app, :inspector => true)
end
#give travis some time for ajax requests to complete
Capybara.default_wait_time = 15

if Rails::VERSION::MAJOR >= 3
  require 'rake'
  require 'rails/tasks'
  Rake::Task["tmp:create"].invoke
end

