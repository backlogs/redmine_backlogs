require 'date'
require 'yaml'

class RbSprintBurndown < ActiveRecord::Base
  set_table_name 'rb_sprint_burndown'
  belongs_to :version

  serialize :issues, Array
  serialize :burndown, Hash
  after_initialize :set_defaults

  attr_reader :dirty

  def direction
    @direction
  end
  def direction=(dir)
    dir = :up if dir.to_s == ''
    dir = dir.intern if dir.is_a?(String)
    raise "Direction can only be 'up' or 'down', not #{dir.inspect}" unless [:up, :down].include?(dir)
    @direction = dir
  end

  def touch!(issue_id = nil)
    if issue_id
      issue_id = Integer(issue_id)
      return if self.issues.include?(issue_id)
      self.issues << issue_id
    end
    self.burndown = nil
    self.save
  end

  def [](key)
    self.recalculate!
    key = key.intern if key.is_a?(String)
    raise "No burn#{@direction} data series '#{key}', available: #{self.burndown[@direction].keys.inspect}" unless self.burndown[@direction][key]
    return self.burndown[@direction][key]
  end

  def series(remove_empty = true)
    self.recalculate!

    @series ||= {}
    key = "#{@direction}_#{remove_empty ? 'filled' : 'all'}"
    if @series[key].nil?
      @series[key] = self.burndown[@direction].keys.collect{|k| k.to_s}.sort
      if remove_empty
        # delete :points_committed if flatline
        @series[key].delete('points_committed') if self.burndown[@direction][:points_committed].uniq.compact.size < 1

        # delete any series that is flat-line 0/nil
        @series[key].each {|k|
          @series[remove_empty].delete(k) if k != 'points_committed' && self.burndown[@direction][k.intern].collect{|d| d.to_f }.uniq == [0.0]
        }
      end
    end

    return @series[key]
  end

  #compatibility
  def days
    self.recalculate!
    self.burndown[:days]
  end

  def data
    self.recalculate!
    self.burndown[@direction]
  end

  def set_defaults
    self.issues ||= []
    self.direction = Backlogs.setting[:points_burn_direction]
    @dirty = self.burndown.nil? || self.burndown.empty? || !self.updated_at || self.updated_at.to_date < Date.today
  end

  def recalculate!
    return unless @dirty

    # if I use self.version.id I get a "stack level too deep?!
    sprint = RbSprint.find(self.version_id)

    if !sprint.has_burndown?
      self.burndown = nil
      return
    end

    puts "Recalculating for #{sprint.id}"

    _burndown = {}
    days = sprint.days
    ndays = days.size
    [:hours_remaining, :points_committed, :points_accepted, :points_resolved].each{|k| _burndown[k] = [nil] * ndays }
    statuses = RbIssueHistory.statuses
    RbStory.find(:all, :conditions => ['id in (?)', self.issues]).each{|story|
      bd = story.burndown(sprint, statuses)
      next unless bd
      bd.each_pair {|k, data|
        puts "#{k.inspect} #{data.inspect}"
        data.each_with_index{|d, i|
          next unless d
          _burndown[k][i] ||= 0
          _burndown[k][i] += d
        }
      }
    }

    _burndown[:ideal] = (0..ndays - 1).to_a.reverse
    [[:points_to_resolve, :points_resolved], [:points_to_accept, :points_accepted]].each{|todo|
      tgt, src = *todo
      _burndown[tgt] = (0..ndays - 1).to_a.collect{|i| _burndown[:points_committed][i] && _burndown[src][i] ? _burndown[:points_committed][i] - _burndown[src][i] : nil }
    }
    [[:points_required_burn_rate, :points_to_resolve], [:hours_required_burn_rate, :hours_remaining]].each{|todo|
      tgt, src = *todo
      _burndown[tgt] = (0..ndays - 1).to_a.collect{|i| _burndown[src][i] ? Float(_burndown[src][i]) / (_burndown[:ideal][i] == 0 ? 1 : _burndown[:ideal][i]) : nil }
    }

    self.burndown = { :up   => _burndown.reject{|k, v| [:points_to_resolve, :points_to_accept].include?(k) },
                      :down => _burndown.reject{|k, v| [:points_resolved, :points_accepted].include?(k) },
                      :days => days
                    }
    self.save
    @dirty = false
  end
end
