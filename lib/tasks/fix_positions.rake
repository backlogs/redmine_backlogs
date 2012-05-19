namespace :redmine do
  namespace :backlogs do
    desc "Remove duplicate positions in the issues table"
    task :fix_positions => :environment do
      unless Backlogs.migrated?
        puts "Please run plugin migrations first"
      else
        RbStory.connection.execute("drop table if exists _backlogs_tmp_position")
        RbStory.connection.execute("create table _backlogs_tmp_position (issue_id int not null unique, new_position int not null unique)")

        RbStory.transaction do
          RbStory.connection.execute("update issues set position_lock=position")
          
          RbStory.connection.execute("
            insert into _backlogs_tmp_position (issue_id, new_position)
            select id, (select count(*) from issues pred where pred.position < story.position) * #{RbStory::POSITION_GAP}
            from issues story
          ")

          RbStory.connection.execute("
            update issues
            set position = (select new_position from _backlogs_tmp_position where id = issue_id)
          ")

          RbStory.connection.execute("update issues set position_lock=0")
        end

        RbStory.connection.execute("drop table _backlogs_tmp_position")
      end
    end
  end
end
