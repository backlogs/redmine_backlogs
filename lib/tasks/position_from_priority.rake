namespace :redmine do
  namespace :backlogs do
    desc "Remove duplicate positions in the issues table"
    task :position_from_priority => :environment do
      unless Backlogs.migrated?
        puts "Please run plugin migrations first"
      else
        RbStory.transaction do
          ids = RbStory.connection.select_values('select issues.id
                                                  from issues
                                                  join enumerations on issues.priority_id = enumerations.id
                                                  order by enumerations.position desc')
          ids.each_with_index{|id, i|
            RbStory.connection.execute("update issues set position = #{i * RbStory.list_spacing} where id = #{id}")
          }
        end
      end
    end
  end
end
