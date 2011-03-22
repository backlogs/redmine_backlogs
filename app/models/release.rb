require 'date'

# FIXME this is simplified copypasta of the Burndown class from sprint.rb
class ReleaseBurndown
  class Series < Array
    def initialize(*args)
      @name = args.pop

      raise "Name '#{@name}' must be a symbol" unless @name.is_a?  Symbol
      super(*args)
    end

    attr_reader :name
  end

  def initialize(release)
    @days = release.days
    @release_id = release.id

    # end date for graph
    days = @days
    daycount = days.size
    #days = release.days(Date.today) if release.release_end_date > Date.today

    _series = ([nil] * days.size)

    # load cache
    day_index = to_h(days, (0..(days.size - 1)).to_a)
    ReleaseBurndownDay.find(:all, :order=>'day', :conditions => ["release_id = ?", release.id]).each {|data|
      day = day_index[data.day.to_date]
      next if !day

      _series[day] = [data.remaining_story_points.to_f]
    }

    # use initial story points for first day if not loaded from cache (db)
    _series[0] = [release.initial_story_points.to_f] unless _series[0]

    # fill out series
    last = nil
    _series = _series.enum_for(:each_with_index).collect{|v, i| v.nil? ? last : (last = v; v) }

    # make registered series
    remaining_story_points = _series.transpose
    make_series :remaining_story_points, remaining_story_points[0]

    # calculate burn-down ideal
    if daycount == 1 # should never happen
      make_series :ideal, [remaining_story_points[0]]
    else
      day_diff = remaining_story_points[0][0] / (daycount - 1.0)
      make_series :ideal, remaining_story_points[0].enum_for(:each_with_index).collect{|c, i| remaining_story_points[0][0] - i * day_diff }
    end

    @max = @available_series.values.flatten.compact.max
  end

  attr_reader :days
  attr_reader :release_id
  attr_reader :max

  attr_reader :remaining_story_points
  attr_reader :ideal

  def series(select = :active)
    return @available_series.values.select{|s| (select == :all) }.sort{|x,y| "#{x.name}" <=> "#{y.name}"}
  end

  private

  def make_series(name, data)
    @available_series ||= {}
    s = ReleaseBurndown::Series.new(data, name)
    @available_series[name] = s
    instance_variable_set("@#{name}", s)
  end

  def to_h(keys, values)
    return Hash[*keys.zip(values).flatten]
  end

end

class Release < ActiveRecord::Base
    unloadable

    belongs_to :project
    has_many :release_burndown_days, :dependent => :delete_all

    validates_presence_of :project_id, :name, :release_start_date, :release_end_date, :initial_story_points
    validates_length_of :name, :maximum => 64
    validate :dates_valid?

    def dates_valid?
        if self.release_start_date and self.release_end_date
          errors.add_to_base(l(:error_release_end_after_start)) if self.release_start_date >= self.release_end_date
        end
    end

    def stories
        return Story.product_backlog(@project)
    end

    def burndown_days
        self.release_burndown_days.sort { |a,b| a.day <=> b.day }
    end

    def days(cutoff = nil)
        # assumes mon-fri are working days, sat-sun are not. this
        # assumption is not globally right, we need to make this configurable.
        cutoff = self.release_end_date if cutoff.nil?
        workdays(self.release_start_date, cutoff)
    end

    def has_burndown?
        return !!(self.release_start_date and self.release_end_date and self.initial_story_points)
    end

    def burndown
        return nil if not self.has_burndown?
        @cached_burndown ||= ReleaseBurndown.new(self)
        return @cached_burndown
    end

    def today
      ReleaseBurndownDay.find(:first, :conditions => { :release_id => self, :day => Date.today })
    end

    def js_ideal
      "[['#{release_start_date}', #{initial_story_points}], ['#{release_end_date}', 0]]"
    end

    def js_snapshots
      foo = "["
      if burndown_days and burndown_days[0] and burndown_days[0].day != release_start_date
        foo += "['#{release_start_date}', #{initial_story_points}],"
      end
      burndown_days.each { |bdd| foo += "['#{bdd.day}', #{bdd.remaining_story_points}]," }
      foo += "]"
    end
end
