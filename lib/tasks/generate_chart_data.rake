desc 'Generate chart data for all backlogs'

namespace :redmine do
  namespace :backlogs do
    task :generate_chart_data => :environment do
      RbSprint.generate_burndown(!ENV['all'])
    end
  end
end
