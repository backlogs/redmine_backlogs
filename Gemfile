source :rubygems

gem "holidays", "=1.0.3"
gem "icalendar"
gem "nokogiri"
gem "open-uri-cached"
gem "prawn"
gem "system_timer" if RUBY_VERSION =~ /^1\.8\./ && RUBY_PLATFORM =~ /darwin|linux/

# development gems
#puts "RBL dev mode: " + File.join(File.expand_path(File.dirname(__FILE__)), 'Gemfile.dev')
if File.exist?(File.join(File.expand_path(File.dirname(__FILE__)), 'Gemfile.dev')) # this is actually the main Gemfile
  gem 'ZenTest', "=4.5.0" # 4.6.0 has a nasty bug that breaks autotest
  gem 'autotest-rails'
  gem "capybara", "=0.3.9"
  gem "cucumber", "=1.1.2"
  gem "database_cleaner"
  gem "gherkin", "=2.6.2"
  gem "redgreen"
  gem "rspec", "=1.3.1"
  gem "rspec-rails", "=1.3.3"
  gem (RUBY_VERSION >= "1.9" ? "simplecov" : "rcov")
  gem "spork"
  gem "timecop"
  gem "thin"
  gem 'cucumber-rails', '=0.3.2'
end
