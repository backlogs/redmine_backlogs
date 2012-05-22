require 'benchmark'

class FixMissingJournal < ActiveRecord::Migration
  def self.up
    if Backlogs.platform == :redmine
      Issue.find(:all, :conditions => ['tracker_id = ?', RbTask.tracker]).each {|task|
        jd = JournalDetail.find(:first, :order => "journals.created_on desc" , :joins => :journal,
                               :conditions => ["property = 'attr' and prop_key = 'estimated_hours' and journalized_type = 'Issue' and journalized_id = ?", task.id])
        if jd && jd.value.to_f != task.estimated_hours
          nj = Journal.new
          nj.journalized = task
          nj.user = jd.journal.user
          nj.created_on = task.updated_on
  
          njd = JournalDetail.new
          njd.property = 'attr'
          njd.prop_key = 'estimated_hours'
          njd.old_value = jd.value
          njd.value = task.estimated_hours.to_s
  
          nj.details << njd
  
          nj.save!
          execute("delete from rb_journals where issue_id = #{task.id}")
        end
      }
    end
  end

  def self.down
    puts "Reverting irreversible migration"
  end
end
