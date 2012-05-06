# Redmine - project management software
# Copyright (C) 2006-2011  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

class RbJournal < ActiveRecord::Base
  REDMINE_PROPERTIES = ['fixed_version_id', 'status_id', 'story_points', 'remaining_hours']
  JOURNALED_PROPERTIES = ['fixed_version_id', 'status_open', 'status_success', 'story_points', 'remaining_hours']

  belongs_to :issue

  def self.journal(j)
    case Backlogs.platform
      when :redmine
        issue_id = j.journalized_id
        timestamp = j.created_on

        j.details.each{|detail|
          next unless detail.property == 'attr'
          next unless RbJournal::REDMINE_PROPERTIES.include?(detail.prop_key)
          if detail.prop_key == 'status_id'
            begin
              status = IssueStatus.find(detail.value)
            rescue ActiveRecord::RecordNotFound
              status = nil
            end
            RbJournal.new(:issue_id => issue_id, :timestamp => timestamp, :property => 'status_open', :value => status && !status.is_closed? : nil).save
            RbJournal.new(:issue_id => issue_id, :timestamp => timestamp, :property => 'status_success', :value => status && !status.backlog_is?(:success) : nil).save
          else
            RbJournal.new(:issue_id => issue_id, :timestamp => timestamp, :property => detail.prop_key, :value => detail.value).save
          end
        }

      when :chiliproject
        if j.type == 'IssueJournal'
          issue_id = j.journaled_id
          timestamp = j.created_on

          RbJournal::REDMINE_PROPERTIES.each{|prop|
            next if j.details[prop].nil?

            if prop == 'status_id'
              begin
                status = IssueStatus.find(j.details[prop][1])
              rescue ActiveRecord::RecordNotFound
                status = nil
              end
              RbJournal.new(:issue_id => issue_id, :timestamp => timestamp, :property => 'status_open', :value => status && !status.is_closed? : nil).save
              RbJournal.new(:issue_id => issue_id, :timestamp => timestamp, :property => 'status_success', :value => status && !status.backlog_is?(:success) : nil).save
            else
              RbJournal.new(:issue_id => issue_id, :timestamp => timestamp, :property => prop, :value => j.details[prop][1]).save
            end
          }
        end
    end
  end

  def self.rebuild(issue)
    RbJournal.delete_all(:issue_id => issue.id)

    changes = {}
    RbJournal::REDMINE_PROPERTIES.each{|prop| changes[prop] = [] }

    case Backlogs.platform
      when :redmine
        JournalDetail.find(:all, :order => "journals.created_on asc" , :joins => :journal,
                                           :conditions => ["property = 'attr' and prop_key in (?)
                                                and journalized_type = 'Issue' and journalized_id = ?",
                                                RbJournal::REDMINE_PROPERTIES, issue.id]).each {|detail|
          changes[detail.prop_key] << {:time => detail.journal.created_on, :old => detail.old_value, :new => detail.value}
        }
          
      when :chiliproject
        # has to be here because the ChiliProject journal design easily allows for one to delete issue statuses that remain
        # in the journal, because even the already-feeble rails integrity constraints can't be enforced. This also mean it's
        # not really reliable to use statuses for historic burndown calculation. Those are the breaks if you let programmers
        # do database design.
        valid_statuses = IssueStatus.connection.select_values("select id from #{IssueStatus.table_name}").collect{|x| x.to_i}

        issue.journals.reject{|j| j.created_at < issue.created_on}.each{|j|
          RbJournal::REDMINE_PROPERTIES.each{|prop|
            delta = j.changes[prop]
            next unless delta
            if prop == 'status_id'
              next if changes[prop].size == 0 && !valid_statuses.include?(delta[0])
              next unless valid_statuses.include?(delta[1])
            end
            changes[prop] << {:time => j.created_at, :old => delta[0], :new => delta[1]}
          }
        }
    end

    RbJournal::REDMINE_PROPERTIES.each{|prop|
      if changes[prop].size > 0
        changes[prop].unshift({:time => issue.created_on, :new => changes[prop][0][:old]})
      else
        changes[prop] = [{:time => issue.created_on, :new => issue.send(prop.intern)}]
      end
    }

    issue_status = {}
    changes['status_id'].collect{|change| change[:new]}.compact.uniq.each{|id|
      begin
        issue_status[id] = IssueStatus.find(Integer(id))
      rescue ActiveRecord::RecordNotFound
        issue_status[id] = nil
      end
    }

    ['status_open', 'status_success'].each{|p| changes[p] = [] }
    changes['status_id'].each{|change|
      status = issue_status[change[:new]]
      changes['status_open'] << change.merge(:new => status && !status.is_closed?)
      changes['status_success'] << change.merge(:new => status && status.backlog_is?(:success))
    }
    changes.delete('status_id')

    changes.each_pair{|prop, updates|
      updates.each{|change|
        RbJournal.new(:issue_id => issue.id, :property => prop, :timestamp => change[:time], :value => change[:new]).save
      }
    }
  end

  def to_s
    "<#{RbJournal.table_name} issue=#{issue_id}: #{property}=#{value.inspect} @ #{timestamp}>"
  end

  def self.changes_to_s(changes, prefix = '')
    s = ''
    changes.each_pair{|k, v|
      s << "#{prefix}#{k}\n"
      v.each{|change|
        s << "#{prefix}  @#{change[:time]}: #{change[:new]}\n"
      }
    }
    return s
  end

  def property
    return self[:property].to_sym
  end
  def property=(name)
    raise "Unknown journal property #{name.inspect}" unless RbJournal::JOURNALED_PROPERTIES.include?(name.to_s)
    self[:property] = name.to_s
  end

  def value
    v = self[:value]

    return nil if v.nil?
    return nil if v == "nil"

    case property
      when :status_open, :status_success
        return (v == 'true')
      when :fixed_version_id, :status_id
        return Integer(v)
      when :story_points, :remaining_hours
        return Float(v)
      else
        raise "Unknown journal property #{property.inspect}"
    end
  end
  def value=(v)
    self[:value] = v.nil? ? nil : v.to_s
  end
end
