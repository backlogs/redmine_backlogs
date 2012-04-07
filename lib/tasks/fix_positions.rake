namespace :redmine do
  namespace :backlogs do
    desc "Remove duplicate positions in the issues table"
    task :fix_positions => :environment do
      if RbStory.trackers.size > 0
        # non-story issues get no position
        RbStory.connection.execute("update issues set position = null where not tracker_id in (#{RbStory.trackers(:type=>:string)})")

        # make positions unique
        repeat = true
        while repeat
          repeat = false
          RbStory.find_by_sql("select position, count(*) as duplicates
                               from issues
                               where not position is null and tracker_id in (#{RbStory.trackers(:type=>:string)})
                               group by position
                               having count(*) > 1").each {|duplicate|
            repeat = true

            puts "Found position #{duplicate.position} #{duplicate.duplicates} times"

            RbStory.connection.execute("update issues set position = position + #{duplicate.duplicates} where position > #{duplicate.position}")

            RbStory.find_by_position(duplicate.position).each_with_index{|story, i|
              RbStory.connection.execute("update issues set position = position + #{i} where id = #{story.id}")
            }
            break
          }
        end

        # assign null-positioned stories a position at the end
        story = RbStory.find_by_sql('select max(position) as highest from issues')
        max = story ? (story[0].highest.to_i + 1) : 1
        RbStory.find_by_sql("select id from issues where tracker_id in (#{RbStory.trackers(:type=>:string)}) and position is null").each_with_index{|story, i|
          puts "Assigning position #{max + i} to #{story.id}"
          RbStory.connection.execute("update issues set position = #{max + i} where id = #{story.id}")
        }

        # close gaps
        story = RbStory.find_by_sql("select min(position) as lowest from issues")
        RbStory.connection.execute("update issues set position = (position - #{story[0].lowest}) + 1") if story

        repeat = true
        while repeat
          repeat = false
          RbStory.find_by_sql("select id, position,
                                  (select min(position) from issues where tracker_id in (#{RbStory.trackers(:type=>:string)}) and position > pregap.position) as postgap
                               from issues pregap
                               where tracker_id in (#{RbStory.trackers(:type=>:string)})
                                  and not exists(select * from issues where position = pregap.position + 1)").each{|pregap|
            if pregap.postgap
              puts "Closing gap between #{pregap.position} and #{pregap.postgap}"
              RbStory.connection.execute("update issues set position = (position + 1) - #{pregap.postgap.to_i - pregap.position.to_i} where position > #{pregap.position}")
              repeat = true
            else
              repeat = false
            end
            break
          }
        end

      end
    end
  end
end
