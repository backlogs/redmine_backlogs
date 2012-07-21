source :rubygems

chiliproject_file = File.dirname(__FILE__) + "/lib/chili_project.rb"
chiliproject = File.file?(chiliproject_file)

deps = Hash.new
@dependencies.map{|dep| deps[dep.name] = dep }
rails3 = Gem::Dependency.new('rails', '~>3.0')
RAILS_VERSION_IS_3 = rails3 =~ deps['rails']

gem "holidays", "=1.0.3"
gem "icalendar"
gem "nokogiri"
gem "open-uri-cached"
gem "prawn"
gem 'json'
gem "system_timer" if RUBY_VERSION =~ /^1\.8\./ && RUBY_PLATFORM =~ /darwin|linux/

group :development do
  gem "github-v3-api"
  gem "inifile"
end

group :test do
  gem 'ZenTest', "=4.5.0" # 4.6.0 has a nasty bug that breaks autotest
  gem 'autotest-rails'
  if RAILS_VERSION_IS_3
    gem 'capybara' unless chiliproject
    gem 'cucumber-rails'
    gem "culerity"
  else
    unless chiliproject
      gem "capybara", "~>1.1.0"
    end
    gem "cucumber", "=1.1.0"
    gem 'cucumber-rails2', "~> 0.3.5"
    gem "culerity", "=0.2.15"
  end
  gem "database_cleaner"
  if RAILS_VERSION_IS_3
    gem "gherkin", "=2.6.8"
    gem 'hoe', '1.5.1'
  else
    gem "gherkin", "~> 2.5.0"
  end
  gem "poltergeist"
  gem "redgreen" if RUBY_VERSION < "1.9"
  if RAILS_VERSION_IS_3
    gem "rspec", "=2.5.0"
    gem "rspec-rails", "=2.5.0"
  else
    gem "rspec", "=1.3.1"
    gem "rspec-rails", "=1.3.3"
  end
  if RUBY_VERSION >= "1.9"
    gem "simplecov", "~>0.6"
  else
    gem "rcov",  "=0.9.11"
  end
  gem "spork"
  gem "test-unit", "=1.2.3" if RUBY_VERSION >= "1.9"
  gem "timecop"
end

# moved out of the dev group so backlogs can be tested by the user after install. Too many issues of weird setups with apache, nginx, etc.
# thin doesn't work for jruby
gem "thin", :platforms => [:ruby]
