# Sets up the Rails environment for Cucumber
ENV["RAILS_ENV"] = "test"
require File.expand_path(File.dirname(__FILE__) + '/../../config/environment')
require 'cucumber/rails/world'
Cucumber::Rails::World.use_transactional_fixtures

Before do # a little longer, but more reliable
#Seed the DB
Fixtures.reset_cache  
fixtures_folder = File.join(Rails.root, 'test', 'fixtures')
fixtures = Dir[File.join(fixtures_folder, '*.yml')].map {|f| File.basename(f, '.yml') }
Fixtures.create_fixtures(fixtures_folder, fixtures)
end

if Cucumber::Rails.respond_to?('Database')
  # only for recent cucumber-rails
  # do not clean the database between @javascript scenarios
  Cucumber::Rails::Database.javascript_strategy = :transaction
end
DatabaseCleaner.strategy = nil # much faster than truncation

# use headless webkit to test javascript ui
require 'capybara/poltergeist'
Capybara.javascript_driver = :poltergeist
Capybara.register_driver :poltergeist do |app|
  Capybara::Poltergeist::Driver.new(app, :inspector => true)
end
