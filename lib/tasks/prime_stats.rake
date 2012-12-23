namespace :redmine do
  namespace :backlogs do
    desc "Prime the statistics cache"
    task :prime_stats => :environment do
      projects = RbCommonHelper.find_backlogs_enabled_active_projects
      projects.each{|project|
        puts project.name
        project.scrum_statistics(:force)
      }
    end
  end
end
