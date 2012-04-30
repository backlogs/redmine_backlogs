namespace :redmine do
  namespace :backlogs do
    desc "Remove duplicate positions in the issues table"
    task :fix_positions => :environment do
      if RbStory.trackers.size > 0
        # non-story issues get no position
        RbStory.connection.execute("update issues set position = null where not tracker_id in (#{RbStory.trackers(:type=>:string)})")

        newpos = 0
        RbStory.find_by_sql("select coalesce(max(position), -1) + 1 as newpos from issues where not position is null and tracker_id in (#{RbStory.trackers(:type=>:string)})").each{|row|
          newpos = row[0].to_i
        }
        RbStory.connection.execute("update issues set position = #{newpos} where position is null and tracker_id in (#{RbStory.trackers(:type=>:string)})")

        RbStory.connection.execute("create table _backlogs_tmp_position (issue_id int not null unique, new_position int not null unique)")

        RbStory.connection.execute("
          insert into _backlogs_tmp_position (issue_id, new_position)
          select id, (
              select count(*)
              from issues pred
              where 
                (pred.position < story.position)
                or
                (pred.position = story.position and pred.id < story.id)
            )
          from issues story
          where story.tracker_id in (#{RbStory.trackers(:type=>:string)})
        ")

        RbStory.connection.execute("
          select count(*) as to_update from issues
          left join _backlogs_tmp_position on id = issue_id
          where (issue_id is null or position <> new_position)
                and tracker_id in (#{RbStory.trackers(:type=>:string)})").each{|row|
          puts "Updating #{row[0]} positions"
        }

        RbStory.connection.execute("update issues set position = null where tracker_id in (#{RbStory.trackers(:type=>:string)})")
        RbStory.connection.execute("
          update issues
          set position = (select new_position from _backlogs_tmp_position where id = issue_id)
          where id in (select issue_id from _backlogs_tmp_position)
        ")
        RbStory.connection.execute("drop table _backlogs_tmp_position")
        RbStory.connection.execute("select count(*) as not_updated from issues where position is null and tracker_id in (#{RbStory.trackers(:type=>:string)})").each{|row|
          next if row[0].to_i == 0
          puts "#{row[0]} stories not updated!"
        }
      end
    end
  end
end
