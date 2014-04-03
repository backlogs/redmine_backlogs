source 'https://rubygems.org'

redmine_version_file = File.expand_path("../../../lib/redmine/version.rb",__FILE__)
if (!File.exists? redmine_version_file)
  redmine_version_file = File.expand_path("lib/redmine/version.rb");
end
version_file = IO.read(redmine_version_file)
redmine_version_minor = version_file.match(/MINOR =/).post_match.match(/\d/)[0].to_i
redmine_version_major = version_file.match(/MAJOR =/).post_match.match(/\d/)[0].to_i

chiliproject_file = File.dirname(__FILE__) + "/lib/chili_project.rb"
chiliproject = File.file?(chiliproject_file)

deps = Hash.new
@dependencies.map{|dep| deps[dep.name] = dep }
rails3 = Gem::Dependency.new('rails', '~>3.0')
RAILS_VERSION_IS_3 = rails3 =~ deps['rails']

gem "holidays", "~>1.0.3"
gem "icalendar"
# Choose nokogiri depending on RM version. This is done to avoid conflict with
# RM 2.3 which pinned nokogiri at "<1.6.0" for group :test.
if (redmine_version_major == 2 && redmine_version_minor == 3)
gem "nokogiri", "< 1.6.0"
else
gem "nokogiri"
end
gem "open-uri-cached"
gem "prawn"
gem 'json'
gem "system_timer" if RUBY_VERSION =~ /^1\.8\./ && RUBY_PLATFORM =~ /darwin|linux/

group :development do
  gem "inifile"
end

group :test do
  gem 'chronic'
  gem 'ZenTest', "=4.5.0" # 4.6.0 has a nasty bug that breaks autotest
  gem 'autotest-rails'
  if RAILS_VERSION_IS_3
    unless chiliproject
      gem 'capybara', "~> 1.1" if ENV['IN_RBL_TESTENV'] == 'true' # redmine 2.3 conflicts
      gem "faye-websocket", "~>0.4.7"
      gem "poltergeist", "~>1.0"
    end
    gem 'cucumber-rails', :require => false
    gem "culerity"
  else
    unless chiliproject
      gem "capybara", "~>1.1.0"
      gem "poltergeist", "~>0.6.0"
    end
    gem "cucumber", "=1.1.0"
    gem 'cucumber-rails2', "~> 0.3.5"
    gem "culerity", "=0.2.15"
  end
  gem "database_cleaner"
  if RAILS_VERSION_IS_3
    gem "gherkin", "~> 2.6"
  else
    gem "gherkin", "~> 2.5.0"
  end
  gem "redgreen" if RUBY_VERSION < "1.9"
  if RAILS_VERSION_IS_3
    gem "rspec", '~>2.11.0'
    gem "rspec-rails", '~> 2.11.0'
  else
    gem "rspec", "=1.3.1"
    gem "rspec-rails", "=1.3.3"
  end
  if RUBY_VERSION >= "1.9"
    gem "simplecov", "~>0.6"
  else
    gem "rcov",  "=0.9.11"
  end
  gem "ruby-prof", :platforms => [:ruby]
  gem "spork"
  gem "test-unit", "=1.2.3" if RUBY_VERSION >= "1.9" and ENV['IN_RBL_TESTENV'] == 'true'
  gem "timecop", '~> 0.3.5'
end

# moved out of the dev group so backlogs can be tested by the user after install. Too many issues of weird setups with apache, nginx, etc.
# thin doesn't work for jruby
gem "thin", :platforms => [:ruby]
