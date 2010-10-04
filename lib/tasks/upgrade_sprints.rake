require 'active_record'

namespace :redmine do
  namespace :backlogs do 
    desc "Upgrade sprints to use sprints table. WARNING: Causes irreversable changes"
    task :upgrade_sprints => :environment do |t|
      ENV["RAILS_ENV"] ||= "development"
      do_upgrade
    end
  end
end

def do_upgrade
  ActiveRecord::Base.transaction {
    Version.find(:all, :conditions => 'not (sprint_start_date is null or effective_date is null)').each {|version|
      sprint = Sprint.find(:first, :conditions => ['project_id = ? and start_date = ? and end_date = ?', version.project.id, version.sprint_start_date, version.effective_date])
      next if sprint

      puts "Creating sprint "#{version.name}"

      sprint = Sprint.new
      sprint.project = version.project
      sprint.name = version.name
      sprint.description = version.description
      sprint.start_date = version.sprint_start_date
      sprint.end_date = version.effective_date
      sprint.wiki_page_title = version.wiki_page_title
      sprint.created_on = version.created_on
      sprint.updated_on = version.updated_on
      sprint.save

      BurndownDay.connection.execute("update burndown_days set sprint_id = #{sprint.id.to_i}, project_id = #{sprint.project_id.to_i} where version_id = #{version.id.to_i}")

      Issue.connection.execute("update issues set sprint_id = #{sprint.id.to_i} where fixed_version_id = #{version.id.to_i}")
    }
    BurndownDay.connection.execute("delete from burndown_days where sprint_id not in (select id from sprints)")
  }
end
