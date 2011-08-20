require 'benchmark'

class FixMissingJournal < ActiveRecord::Migration
  def self.up
    issues = Issue.all.each {|issue|
      jd = JournalDetail.find(:first, :order => "journals.created_on desc" , :joins => :journal,
                             :conditions => ["property = 'attr' and prop_key = 'estimated_hours' and journalized_type = 'Issue' and journalized_id = ?", id])
      if jd && jd.value.to_f != issue.estimated_hours
        puts issue.id
        nj = Journal.new
        nj.journalized = issue
        nj.user = jd.journal.user
        nj.created_on = issue.updated_on

        njd = JournalDetail.new
        njd.property = 'attr'
        njd.prop_key = 'estimated_hours'
        njd.old_value = jd.value
        njd.value = issue.estimated_hours.to_s

        nj.details << njd

        nj.save!
      end
    }
  end

  def self.down
    raise ActiveRecord::IrreversibleMigration
  end
end
