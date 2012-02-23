source :rubygems

gem "holidays", "=1.0.3"
gem "icalendar"
gem "nokogiri"
gem "open-uri-cached"
gem "prawn"
gem "system_timer" if RUBY_VERSION =~ /^1\.8\./ && RUBY_PLATFORM =~ /darwin|linux/

group :mysql do
  gem "mysql"
end

group :postgresql do
  gem "pg"
end

group :development do
  gem "capybara", "=0.3.9"
  gem "cucumber", "=1.1.2"
  gem "database_cleaner"
  gem "gherkin", "=2.6.8"
  gem "spork"
  gem "rcov" if RUBY_VERSION =~ /^1\.8\./
  gem "simplecov" if RUBY_VERSION =~ /^1\.9\./
  gem "redgreen"
  gem "rspec", "=1.3.1"
  gem "rspec-rails", "=1.3.3"
  gem "timecop"
  gem "thin"
  gem 'rb-fsevent', :require => false if RUBY_PLATFORM =~ /darwin/i
  gem 'guard-cucumber'
end
