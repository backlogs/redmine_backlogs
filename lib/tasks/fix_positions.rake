namespace :redmine do
  namespace :backlogs do
    desc "Remove duplicate positions in the issues table"
    task :fix_positions => :environment do
      unless Backlogs.migrated?
        puts "Please run plugin migrations first"
      else
        RbStory.connection.execute("drop table if exists _backlogs_tmp_position")

        RbStory.transaction do
          RbStory.connection.execute("update issues set position_lock=position")
          ids = RbStory.connection.select_values('select id from issues order by position')
          ids.each_with_index{|id, i|
            RbStory.connection.execute("update issues set position = #{i * RbStory.list_spacing} where id = #{id}")
          }
          RbStory.connection.execute("update issues set position_lock=0")
        end
      end
    end
  end
end
