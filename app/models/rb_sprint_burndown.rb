require 'date'
require 'yaml'

class RbSprintBurndown < ActiveRecord::Base
  self.table_name = 'rb_sprint_burndown'
  belongs_to :version

  attr_accessible :directon, :version_id, :stories, :burndown

  serialize :stories, Array
  serialize :burndown, Hash
  after_initialize :init

  def direction
    @direction
  end
  def direction=(dir)
    dir = :up if dir.to_s == ''
    dir = dir.intern if dir.is_a?(String)
    raise "Direction can only be 'up' or 'down', not #{dir.inspect}" unless [:up, :down].include?(dir)
    @direction = dir
  end

  def touch!(story_id = nil)
    if story_id
      story_id = Integer(story_id)
      return if self.stories.include?(story_id)
      self.stories << story_id
    end
    self.burndown = nil
    self.save!
    #begin
    #  self.save!
    #rescue => e
    #  Rails.logger.warn e; Rails.logger.warn e.backtrace.join("\n")
    #end
  end

#  This causes a recursive call to recalculate. I don't know why yet
#  def [](key)
#    self.recalculate!
#    key = key.intern if key.is_a?(String)
#    raise "No burn#{@direction} data series '#{key}', available: #{self.burndown[@direction].keys.inspect}" unless self.burndown[@direction][key]
#    return self.burndown[@direction][key]
#  end

  def series(remove_empty = true)
    @series ||= {}
    key = "#{@direction}_#{remove_empty ? 'filled' : 'all'}"
    if @series[key].nil?
      @series[key] = self.get_burndown[@direction].keys.collect{|k| k.to_s}.sort
      if remove_empty
        # delete :points_committed if flatline
        @series[key].delete('points_committed') if self.get_burndown[@direction][:points_committed].uniq.compact.size < 1

        # delete any series that is flat-line 0/nil
        @series[key].each {|k|
          @series[key].delete(k) if k != 'points_committed' && self.get_burndown[@direction][k.intern].collect{|d| d.to_f }.uniq == [0.0]
        }
      end
    end

    return @series[key]
  end

  #compatibility
  def days
    return self.get_burndown[:days]
  end

  def cached_data
    return self.cached_burndown[@direction]
  end
  def data
    return self.get_burndown[@direction]
  end

  def init
    self.stories ||= []
    self.direction = Backlogs.setting[:points_burn_direction]
  end

  def cached_burndown
    cb = read_attribute(:burndown)
    return cb unless cb.nil? || cb.empty?
    get_burndown
  end

  def get_burndown
    return @_burndown if defined?(@_burndown)

    @_burndown = read_attribute(:burndown)
    @_burndown = nil if !@_burndown || @_burndown.size == 0

    # if I use self.version.id I get a "stack level too deep?!
    sprint = self.version # RbSprint.find(self.version_id)

    if !sprint.has_burndown?
      @_burndown = nil
    else
      @_burndown = {}
      days = sprint.days
      ndays = days.size
      [:hours_remaining, :points_committed, :points_accepted, :points_resolved].each{|k| @_burndown[k] = [nil] * ndays }
      statuses = RbIssueHistory.statuses

      RbStory.where(id: self.stories).find_each{|story|
        bd = story.burndown(sprint, statuses)
        next unless bd
        bd.each_pair {|k, data|
          data.each_with_index{|d, i|
            next unless d
            @_burndown[k][i] ||= 0
            @_burndown[k][i] += d.to_f
          }
        }
      }

      @_burndown[:ideal] = (0..ndays - 1).to_a.reverse
      [[:points_to_resolve, :points_resolved], [:points_to_accept, :points_accepted]].each{|todo|
        tgt, src = *todo
        @_burndown[tgt] = (0..ndays - 1).to_a.collect{|i|
          @_burndown[:points_committed][i] && @_burndown[src][i] ? @_burndown[:points_committed][i] - @_burndown[src][i] : nil
        }
      }

      [[:points_required_burn_rate, :points_to_resolve], [:hours_required_burn_rate, :hours_remaining]].each{|todo|
        tgt, src = *todo
        @_burndown[tgt] = (0..ndays - 1).to_a.collect{|i|
          @_burndown[src][i] ? Float(@_burndown[src][i]) / (@_burndown[:ideal][i] == 0 ? 1 : @_burndown[:ideal][i]) : nil
        }
      }

      @_burndown = { :up   => @_burndown.reject{|k, v| [:points_to_resolve, :points_to_accept].include?(k) },
                     :down => @_burndown.reject{|k, v| [:points_resolved, :points_accepted].include?(k) },
                     :days => days
                   }
    end

    cur = read_attribute(:burndown)
    write_attribute(:burndown, @_burndown)
    self.save if @_burndown != cur
    return @_burndown
  end
end
