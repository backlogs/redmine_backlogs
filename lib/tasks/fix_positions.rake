namespace :redmine do
  namespace :backlogs do
    desc "Remove duplicate positions in the issues table"
    task :fix_positions => :environment do
      if RbStory.trackers.size > 0
        # non-story issues get no position
        RbStory.connection.execute("UPDATE issues SET position = NULL WHERE NOT tracker_id IN (#{RbStory.trackers(:type => :string)})")

        newpos = 0
        RbStory.find_by_sql("SELECT COALESCE(MAX(position), -1) + 1 AS newpos FROM issues WHERE NOT position IS NULL AND tracker_id IN (#{RbStory.trackers(:type => :string)})").each{|row|
          newpos = row[0].to_i
        }
        RbStory.connection.execute("UPDATE issues SET position = #{newpos} WHERE position IS NULL AND tracker_id IN (#{RbStory.trackers(:type => :string)})")

        RbStory.connection.execute("CREATE TABLE _backlogs_tmp_position (issue_id INT NOT NULL UNIQUE, new_position INT NOT NULL UNIQUE)")

        RbStory.connection.execute("
          INSERT INTO _backlogs_tmp_position (issue_id, new_position)
          SELECT id, (
              SELECT COUNT(*)
              FROM issues pred
              WHERE
                (pred.position < story.position)
                OR
                (pred.position = story.position AND pred.id < story.id)
            )
          FROM issues story
          WHERE story.tracker_id IN (#{RbStory.trackers(:type => :string)})
        ")

        RbStory.connection.execute("
          SELECT COUNT(*) AS to_update FROM issues
          LEFT JOIN _backlogs_tmp_position ON id = issue_id
          WHERE (issue_id IS NULL OR position <> new_position)
                AND tracker_id IN (#{RbStory.trackers(:type => :string)})").each{|row|
          puts "Updating #{row[0]} positions"
        }

        RbStory.connection.execute("UPDATE issues SET position = NULL WHERE tracker_id IN (#{RbStory.trackers(:type => :string)})")
        RbStory.connection.execute("
          UPDATE issues
          SET position = (SELECT new_position FROM _backlogs_tmp_position WHERE id = issue_id)
          WHERE id IN (SELECT issue_id FROM _backlogs_tmp_position)
        ")
        RbStory.connection.execute("DROP TABLE _backlogs_tmp_position")
        RbStory.connection.execute("SELECT COUNT(*) AS not_updated FROM issues WHERE position IS NULL AND tracker_id IN (#{RbStory.trackers(:type => :string)})").each{|row|
          next if row[0].to_i == 0
          puts "#{row[0]} stories not updated!"
        }
      end
    end
  end
end
