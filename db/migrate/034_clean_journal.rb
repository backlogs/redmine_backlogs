require 'benchmark'

class CleanJournal < ActiveRecord::Migration
  def self.up
    execute("drop table if exists _backlogs_tmp_journal")

    execute("create table _backlogs_tmp_journal (del_for_issue_id int not null unique)")

    execute("
      insert into _backlogs_tmp_journal (del_for_issue_id)
      select distinct issues.id
      from issues
      join rb_journals on issues.id = issue_id
      where rb_journals.value = ''
    ")

    execute("delete from rb_journals where issue_id in (select del_for_issue_id from _backlogs_tmp_journal)")
    execute("drop table _backlogs_tmp_journal")
  end

  def self.down
    # pass
  end
end
