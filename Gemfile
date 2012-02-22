source :rubygems

# needed only if you want to use mysql database
gem "mysql"

gem "holidays", "=1.0.3"
gem "icalendar"
gem "nokogiri"
gem "open-uri-cached"
gem "prawn"
gem "system_timer" if RUBY_VERSION =~ /^1\.8\./ && RUBY_PLATFORM =~ /darwin|linux/

group :development do
  # Gems used only for development and are not required to run backlogs
  #gem "autotest-rails"
  gem "capybara", "=0.3.9"
  gem "cucumber", "=1.1.2"
  gem "cucumber-rails", "=0.3.2"
  gem "database_cleaner"
  gem "gherkin", "=2.6.8"
  gem "spork"
  gem "rcov"
  gem "redgreen"
  gem "rspec", "=1.3.1"
  gem "rspec-rails", "=1.3.3"
  gem "timecop"
  gem "thin"
  # ZenTest 4.6.2 and higher requires RubyGems ~1.8
  gem "ZenTest", "=4.6.0"
end
