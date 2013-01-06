if RUBY_VERSION >= "1.9"
  require 'simplecov'
  SimpleCov.start 'rails' do
    add_group('Backlogs', 'redmine_backlogs')
  end
end
