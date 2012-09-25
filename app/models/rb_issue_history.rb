require 'pp'

class RbIssueHistory < ActiveRecord::Base
  set_table_name 'rb_issue_history'
  belongs_to :issue

  serialize :history, Array
  after_initialize :set_default_history
  after_save :touch_sprint

  def self.statuses
    Hash.new{|h, k|
      s = IssueStatus.find_by_id(k.to_i)
      if s.nil?
        s = IssueStatus.default
        puts "IssueStatus #{k.inspect} not found, using default #{s.id} instead"
      end
      h[k] = {:id => s.id, :open => ! s.is_closed?, :success => s.is_closed? ? (s.default_done_ratio.nil? || s.default_done_ratio == 100) : false }
      h[k]
    }
  end

  def filter(sprint, status=nil)
    h = Hash[*(self.expand.collect{|d| [d[:date], d]}.flatten)]
    sprint.days.collect{|d| h[d] ? h[d] : {:date => d, :origin => :filter}}
  end

  def self.issue_type(tracker_id)
    return if tracker_id.nil? || tracker_id == ''
    tracker_id = tracker_id.to_i
    return :story if RbStory.trackers && RbStory.trackers.include?(tracker_id)
    return :task if tracker_id == RbTask.tracker
    return nil
  end

  def expand
    (0..self.history.size - 2).to_a.collect{|i|
      (self.history[i][:date] .. self.history[i+1][:date] - 1).to_a.collect{|d|
        self.history[i].merge(:date => d)
      }
    }.flatten
  end

  def self.rebuild_issue(issue, status=nil)
    rb = RbIssueHistory.new(:issue_id => issue.id)

    rb.history = [{:date => issue.created_on.to_date - 1, :origin => :rebuild}]

    status ||= self.statuses

    sprints_touched = []
    sprints_touched << issue.fixed_version_id if issue.fixed_version_id

    issue.journals.each{|journal|
      date = journal.created_on.to_date
      journal.details.each{|jd|
        next unless jd.property == 'attr'

        changes = {:prop => jd.prop_key.intern, :old => jd.old_value, :new => jd.value}

        case changes[:prop]
        when :estimated_hours, :story_points, :remaining_hours
          [:old, :new].each{|k| changes[k] = Float(changes[k]) unless changes[k].nil? }
        when :fixed_version_id
          changes[:prop] = :sprint
          [:old, :new].each{|k|
            next if changes[k].nil?
            changes[k] = Integer(changes[k])
            sprints_touched << changes[k]
          }
        when :status_id
          changes = [changes.dup, changes.dup, changes.dup]
          [:id, :open, :success].each_with_index{|prop, i|
            changes[i][:prop] = "status_#{prop}".intern
            [:old, :new].each{|k| changes[i][k] = status[changes[i][k]][prop] }
          }
        when :tracker_id
          changes[:prop] = :tracker
          [:old, :new].each{|k| changes[k] = RbIssueHistory.issue_type(changes[k]) }
        else
          next
        end

        changes = [changes] unless changes.is_a?(Array)
        changes.each{|change|
          rb.history[0][change[:prop]] = change[:old] unless rb.history[0].include?(change[:prop])
          if date != rb.history[-1][:date]
            rb.history << rb.history[-1].dup
            rb.history[-1][:date] = date
          end
          rb.history[-1][change[:prop]] = change[:new]
          rb.history.each{|h| h[change[:prop]] = change[:new] unless h.include?(change[:prop]) }
        }
      }
    }
    rb.history.each{|h|
      h[:estimated_hours] = issue.estimated_hours             unless h.include?(:estimated_hours)
      h[:story_points] = issue.story_points                   unless h.include?(:story_points)
      h[:remaining_hours] = issue.remaining_hours             unless h.include?(:remaining_hours)
      h[:tracker] = RbIssueHistory.issue_type(issue.tracker_id)              unless h.include?(:tracker)
      h[:sprint] = issue.fixed_version_id                     unless h.include?(:sprint)
      h[:status_open] = status[issue.status_id][:open]        unless h.include?(:status_open)
      h[:status_success] = status[issue.status_id][:success]  unless h.include?(:status_success)

      h[:hours] = h[:remaining_hours] || h[:estimated_hours]
    }
    rb.history[-1][:hours] = rb.history[-1][:remaining_hours] || rb.history[-1][:estimated_hours]
    rb.history[0][:hours] = rb.history[0][:estimated_hours] || rb.history[0][:remaining_hours]

    rb.save

    sprints_touched.uniq.each{|sprint_id|
      RbSprintBurndown.find_or_initialize_by_version_id(sprint_id).touch!(issue.id)
    }
  end

  def self.rebuild
    self.delete_all
    RbSprintBurndown.delete_all

    status = self.statuses

    Issue.all.each{|issue|
      puts "#{issue.id}..."
      RbIssueHistory.rebuild_issue(issue, status)
    }
  end

  private

  def set_default_history
    _statuses = self.class.statuses
    self.history ||= []
    self.history << {:date => Date.today, :origin => :default} if self.history.size == 0 || self.history[-1][:date] != Date.today
    self.history[-1].merge!({
      :estimated_hours => self.issue.estimated_hours,
      :story_points => self.issue.story_points,
      :remaining_hours => self.issue.remaining_hours,
      :tracker => RbIssueHistory.issue_type(self.issue.tracker_id),
      :sprint => self.issue.fixed_version_id,
      :status_id => self.issue.status_id,
      :status_open => _statuses[self.issue.status_id][:open],
      :status_success => _statuses[self.issue.status_id][:success]
    })
    self.history[-1][:hours] = self.history[-1][:remaining_hours] || self.history[-1][:estimated_hours]
    self.history[0][:hours] = self.history[0][:estimated_hours] || self.history[0][:remaining_hours]
  end

  def touch_sprint
    RbSprintBurndown.find_or_initialize_by_version_id(self.history[-1][:sprint]).touch!(self.issue.id) if self.history[-1][:sprint]
  end
end
