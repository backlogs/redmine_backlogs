source :rubygems

gem "holidays", "=1.0.3"
gem "icalendar"
gem "nokogiri"
gem "open-uri-cached"
gem "prawn"
gem 'json'
gem "system_timer" if RUBY_VERSION =~ /^1\.8\./ && RUBY_PLATFORM =~ /darwin|linux/

# development gems
#puts "RBL dev mode: " + File.join(File.expand_path(File.dirname(__FILE__)), 'backlogs.dev')
#if File.exist?(File.join(File.expand_path(File.dirname(__FILE__)), 'backlogs.dev')) # this is actually the main Gemfile
group :development do
  gem 'ZenTest', "=4.5.0" # 4.6.0 has a nasty bug that breaks autotest
  gem 'autotest-rails'
  gem "capybara", "~>1.1.0"
  gem "cucumber", "=1.1.0"
  gem 'cucumber-rails', :git => 'https://github.com/Vanuan/cucumber-rails.git', :branch => 'cucumber-rails2_v0.3.3'
  gem "culerity", "=0.2.15"
  gem "database_cleaner"
  gem "gherkin", "~> 2.5.0"
  gem "poltergeist"
  gem "redgreen" if RUBY_VERSION < "1.9"
  gem "rspec", "=1.3.1"
  gem "rspec-rails", "=1.3.3"
  if RUBY_VERSION >= "1.9"
    gem "simplecov", "=0.6.2"
  else
    gem "rcov"
  end
  gem "spork"
  gem "test-unit", "=1.2.3" if RUBY_VERSION >= "1.9"
  gem "timecop"
  gem "thin"
end
