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

class RbStats < ActiveRecord::Base
  REDMINE_PROPERTIES = ['estimated_hours', 'fixed_version_id', 'status_id', 'story_points', 'remaining_hours']
  JOURNALED_PROPERTIES = {
    'estimated_hours'   => :float,
    'remaining_hours'   => :float,
    'story_points'      => :float,
    'fixed_version_id'  => :int,
    'status_open'       => :bool,
    'status_success'    => :bool,
  }

  belongs_to :issue

  def self.journal(j)
    j.rb_journal_properties_saved ||= []

    case Backlogs.platform
      when :redmine
        j.details.each{|detail|
          next if j.rb_journal_properties_saved.include?(detail.prop_key)
          next unless detail.property == 'attr' && RbJournal::REDMINE_PROPERTIES.include?(detail.prop_key)
          j.rb_journal_properties_saved << detail.prop_key
          create_journal(j, detail, j.journalized_id, j.created_on)
        }

      when :chiliproject
        if j.type == 'IssueJournal'
          RbJournal::REDMINE_PROPERTIES.each{|prop|
            next if j.details[prop].nil?
            create_journal(j, prop, j.journaled_id, j.created_on)
          }
        end
    end
  end

  def self.create_journal(j, prop, issue_id, timestamp)
    if journal_property_key(prop) == 'status_id'
      begin
        status = IssueStatus.find(journal_property_value(prop, j))
      rescue ActiveRecord::RecordNotFound
        status = nil
      end
      changes = [ { :property => 'status_open',              :value => status && !status.is_closed },
                  { :property => 'status_success',           :value => status && !status.backlog_is?(:success) } ]
    else
      changes = [ { :property => journal_property_key(prop), :value => journal_property_value(prop, j) } ]
    end
    changes.each{|change|
      RbJournal.new(:issue_id => issue_id, :timestamp => timestamp, :change => change).save
    }
  end

  def self.journal_property_key(property)
    case Backlogs.platform
      when :redmine
        return property.prop_key
      when :chiliproject
        return property
    end
  end

  def self.journal_property_value(property, j)
    case Backlogs.platform
      when :redmine
        return property.value
      when :chiliproject
        return j.details[property][1]
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
        RbJournal.new(:issue_id => issue.id, :timestamp => change[:time], :change => {:property => prop, :value => change[:new]}).save
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

  def change=(prop)
    self.property = prop[:property]
    self.value = prop[:value]
  end
  def property
    return self[:property].to_sym
  end
  def property=(name)
    name = name.to_s
    raise "Unknown journal property #{name.inspect}" unless RbJournal::JOURNALED_PROPERTIES.include?(name)
    self[:property] = name
  end

  def value
    v = self[:value]

    # this test against blank *only* works when not storing string properties! Otherwise test against nil? here and handle
    # blank? per-type
    return nil if v.blank?

    case RbJournal::JOURNALED_PROPERTIES[self[:property]]
      when :bool
        return (v == 'true')
      when :int
        return Integer(v)
      when :float
        return Float(v)
      else
        raise "Unknown journal property #{self[:property].inspect}"
    end
  end
  def value=(v)
    # this test against blank *only* works when not storing string properties! Otherwise test against nil? here and handle
    # blank? per-type
    self[:value] = v.blank? ? nil : case RbJournal::JOURNALED_PROPERTIES[self[:property]]
      when :bool
        v ? 'true' : 'false'
      when :int, :float
        v.to_s
      else
        raise "Unknown journal property #{self[:property].inspect}"
    end
  end
end
