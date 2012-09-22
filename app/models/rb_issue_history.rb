require 'pp'

class RbIssueHistory < ActiveRecord::Base
  set_table_name 'rb_issue_history'
  belongs_to :issue

  serialize :history, Array
  after_initialize :set_default_history

  def self.statuses
    Hash.new{|h, k|
      s = (IssueStatus.find_by_id(k.to_i) || IssueStatus.default)
      h[k] = {:open => ! s.is_closed, :success => s.is_closed ? (s.default_done_ratio.nil? || s.default_done_ratio == 100) : nil }
      h[k]
    }
  end

  def filter(sprint, status=nil)
    h = Hash[*(self.expand(status).collect{|d| [d[:date], d]}.flatten)]
    (sprint.sprint_start_date .. sprint.effective_date + 1).to_a.select{|d| Backlogs.setting[:include_sat_and_sun] ? true : !(d.saturday? || d.sunday?)}.collect{|d| h[d]}
  end

  def expand(status=nil)
    h = self.history.dup

    status ||= RbIssueHistory.statuses
    h << {
      :date => Date.today + 1,
      :estimated_hours => self.issue.estimated_hours,
      :story_points => self.issue.story_points,
      :remaining_hours => self.issue.remaining_hours,
      :sprint => self.issue.fixed_version_id,
      :status_open => status[self.issue.status_id][:open],
      :status_success => status[self.issue.status_id][:success]
    }

    (0..h.size - 2).to_a.collect{|i|
      (h[i][:date] .. h[i+1][:date] - 1).to_a.collect{|d|
        h[i].merge(:date => d)
      }
    }.flatten
  end

  def self.process(source, status=nil)
    if source.is_a?(Issue)
      journals = source.journals
      issue = source
      fill = true
    elsif source.is_a?(Journal)
      journals = [source]
      issue = source.issue
      fill = false
    else
      return
    end

    startdate = issue.created_on.to_date
    rb = (RbIssueHistory.find_by_issue_id(issue.id) || RbIssueHistory.new(:issue_id => issue.id))

    if rb.history.size == 0
      rb.history = [{:date => startdate}]
    else
      fill = false
    end

    status ||= self.statuses

    journals.each{|journal|
      date = journal.created_on.to_date
      if date == startdate
        date += 1 # value on start-of-first-day is oldest value
      elsif journal.created_on.hour != 0 || journal.created_on.min != 0 || journal.created_on.sec != 0
        date -= 1 # if it's not on midnight, assign values to end-of-previous-day
      end

      journal.details.each{|jd|
        next unless jd.property == 'attr'

        changes = [{:prop => jd.prop_key.intern, :old => jd.old_value, :new => jd.value}]

        case changes[0][:prop]
        when :estimated_hours, :story_points, :remaining_hours
          [:old, :new].each{|k| changes[0][k] = Float(changes[0][k]) unless changes[0][k].nil? }
        when :fixed_version_id
          changes[0][:prop] = :sprint
          [:old, :new].each{|k| changes[0][k] = Integer(changes[0][k]) unless changes[0][k].nil? }
        when :status_id
          changes << changes[0].dup
          [:open, :success].each_with_index{|prop, i|
            changes[i][:prop] = "status_#{prop}".intern
            [:old, :new].each{|k| changes[i][k] = status[changes[i][k]][k] }
          }
        else
          next
        end

        changes.each{|change|
          rb.history[0][change[:prop]] = change[:old] unless rb.history[0].include?(change[:prop]) if fill
          next if date <= startdate
          rb.history << rb.history[-1].dup if date != rb.history[-1][:date]
          rb.history[-1][:date] = date
          rb.history.each{|h| h[change[:prop]] = change[:new] unless h.include?(change[:prop]) } if fill
        }
      }
    }
    rb.history.each{|h|
      h[:estimated_hours] = issue.estimated_hours             unless h.include?(:estimated_hours)
      h[:story_points] = issue.story_points                   unless h.include?(:story_points)
      h[:remaining_hours] = issue.remaining_hours             unless h.include?(:remaining_hours)
      h[:sprint] = issue.fixed_version_id                     unless h.include?(:sprint)
      h[:status_open] = status[issue.status_id][:open]        unless h.include?(:status_open)
      h[:status_success] = status[issue.status_id][:success]  unless h.include?(:status_success)
    } if fill

    rb.save
  end

  def self.rebuild
    self.delete_all

    status = self.statuses

    Issue.all.each{|issue| RbIssueHistory.process(issue, status) }
  end

  private

  def set_default_history
    self.history ||= []
  end
end
