require 'rubygems'
require 'yaml'

namespace :redmine do
  namespace :backlogs do
    desc "Prepare fixtures for testing"
    task :prepare_fixtures => :environment do
      root = Rails.root.to_s
      issues = File.join(root, 'test/fixtures/issues.yml')
      data = YAML::load(open(issues))
      data.keys.each_with_index{|k, i| data[k]['position'] = i }
      File.open(issues, 'w') {|f| f.write(data.to_yaml) }
    end
  end
end
