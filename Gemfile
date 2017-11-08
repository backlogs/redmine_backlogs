redmine_version_file = File.expand_path("../../../lib/redmine/version.rb",__FILE__)
if (!File.exists? redmine_version_file)
  redmine_version_file = File.expand_path("lib/redmine/version.rb");
end
version_file = IO.read(redmine_version_file)
redmine_version_minor = version_file.match(/MINOR =/).post_match.match(/\d/)[0].to_i
redmine_version_major = version_file.match(/MAJOR =/).post_match.match(/\d/)[0].to_i

gem "holidays", "~>1.0.3"
gem "icalendar"
gem "open-uri-cached"
gem "prawn"
gem 'json'

group :test do
  gem 'chronic'
  gem 'ZenTest', "=4.5.0" # 4.6.0 has a nasty bug that breaks autotest
  gem 'autotest-rails'
  #gem 'cucumber-rails', '~>1.4.0', require: false
  gem 'cucumber-rails', require: false
  gem "culerity"
  gem "cucumber"
  #gem "faye-websocket"
  gem "poltergeist"
  gem "database_cleaner"
  gem "gherkin"
  gem "rspec"
  gem "rspec-rails"
  gem "ruby-prof", :platforms => [:ruby]
  gem "spork"
  gem "test-unit", "=1.2.3"
  gem "timecop", '~> 0.3.5'
end

