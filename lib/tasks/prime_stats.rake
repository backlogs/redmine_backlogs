namespace :redmine do
  namespace :backlogs do
    desc "Prime the statistics cache"
    task :prime_stats => :environment do
      EnabledModule.find(:all, :conditions => ["enabled_modules.name = 'backlogs' and status = ?", Project::STATUS_ACTIVE], :include => :project, :joins => :project).each{|mod|
        puts mod.project.name
        mod.project.scrum_statistics(:force)
      }
    end
  end
end
