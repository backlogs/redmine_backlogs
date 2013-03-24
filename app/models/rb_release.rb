require 'date'

class ReleaseBurndown
  def initialize(release)
    @days = release.days
    @planned_velocity = release.planned_velocity
    @data = {}

    calculate_burndown(release)
    calculate_trend
    calculate_planned
  end

  def [](i)
    i = i.intern if i.is_a?(String)
    return nil unless @data[i] # be graceful
    #raise "No burn#{@direction} data series '#{i}', available: #{@data.keys.inspect}" unless @data[i]
    return @data[i]
  end

  def series(select = :active)
    return @data.keys.collect{ |k| k.to_s }
#    return @available_series.values.select{|s| (select == :all) }.sort{|x,y| "#{x.name}" <=> "#{y.name}"}
  end

  attr_reader :planned_estimate_end_date
  attr_reader :trend_estimate_end_date

  private

  def calculate_burndown(release)
    @data[:offset_points] = []
    @data[:added_points] = []
    @data[:backlog_points] = []
    @data[:closed_points] = []

    baseline = [0] * @days.size

    series = Backlogs::MergedArray.new
    series.merge(:offset_points => baseline.dup)
    series.merge(:added_points => baseline.dup)
    series.merge(:backlog_points => baseline.dup)
    series.merge(:closed_points => baseline.dup)

    # Go through each story in the release
    release.stories_all_time.each{|story|
      series.add(story.release_burndown_data(@days,release.id))
    }

    # Series collected, now format data for jqplot
    # Slightly hacky formatting to get the correct view. Might change when this jqplot issue is 
    # sorted out:
    # See https://bitbucket.org/cleonello/jqplot/issue/181/nagative-values-in-stacked-bar-chart
    @data[:offset_points] = series.collect{|s| -1 * s.offset_points }
    @data[:added_points] = series.collect{|s| s.backlog_points >= 0 ? s.added_points : s.added_points + s.backlog_points }
    @data[:backlog_points] = series.collect{|s| s.backlog_points >= 0 ? s.backlog_points : 0 }
    @data[:closed_points] = series.series(:closed_points)

    # Keyfigures for later calculations
    @index_estimate_last = calc_index_estimate_last
    @last_backlog_points = @data[:offset_points][@index_estimate_last] +
                             @data[:added_points][@index_estimate_last] +
                             @data[:backlog_points][@index_estimate_last]
    @last_points_left = @last_backlog_points - @data[:offset_points][@index_estimate_last]
    @last_added_points = @data[:offset_points][@index_estimate_last]
    @last_date = release.days[@index_estimate_last]
  end


  def calculate_trend
    @data[:trend_added] = []
    @data[:trend_closed] = []

    return unless @last_points_left > 0
    return unless @index_estimate_last > 0
    avg_count = @index_estimate_last >= 3 ? 3 : @index_estimate_last
    index_estimate_first = @index_estimate_last - avg_count

    avg_days = (@days[@index_estimate_last] - @days[index_estimate_first]).to_i
    avg_added_per_day = (@data[:offset_points][@index_estimate_last] - @data[:offset_points][index_estimate_first]) / avg_days
    avg_closed_per_day = @data[:closed_points][index_estimate_first..@index_estimate_last].inject(0){|sum,p| sum += p} / avg_days * -1

    #Calculate trend end date (crossing trend_closed and trend_added)
    trend_cross_days = (@last_backlog_points - @last_added_points)/(avg_added_per_day - avg_closed_per_day)

    # Value for display in sidebar
    @trend_estimate_end_date = @last_date + trend_cross_days unless trend_cross_days.infinite? or trend_cross_days <= 0

    # Add beginning and end dataset [sprint,points] for trendlines
    trendline_end_date = trend_cross_days.between?(1,365) ? @last_date + trend_cross_days + 30 : @last_date + avg_days

    trendline_days = (trendline_end_date - @last_date).to_i

    @data[:trend_closed] << [@last_date, @last_backlog_points]
    @data[:trend_closed] << [trendline_end_date,
                             @last_backlog_points + (avg_closed_per_day * trendline_days)]
    @data[:trend_added] << [@last_date, @last_added_points]
    @data[:trend_added] << [trendline_end_date,
                            @last_added_points + (avg_added_per_day * trendline_days)]
  end

  def calculate_planned
    return unless @last_points_left > 0
    return unless @planned_velocity.is_a? Float
    return unless @planned_velocity > 0.0

    @data[:planned] = []
    @data[:planned] << [@last_date, @last_backlog_points]
    #FIXME add possibility to choose velocity per week, fortnight, month?
    @planned_estimate_end_date = @last_date + (@last_points_left / @planned_velocity * 30)
    @data[:planned] << [@planned_estimate_end_date, @data[:offset_points][@index_estimate_last]]

  end

  # Calculate index in days array for last date to be included for trend calculations.
  def calc_index_estimate_last
    result = []
    result << 0
    @days.each_with_index{|d,i|
      # Avoid using a date which is within the active sprint. Fallback to previous sprint
      # as data in current sprint is likely not up-to-date
      result << i if d <= Time.now.to_date
    }
    return result[-1]
  end

end

class RbRelease < ActiveRecord::Base
  self.table_name = 'releases'

  RELEASE_STATUSES = %w(open closed)
  RELEASE_SHARINGS = %w(none descendants hierarchy tree system)

  unloadable

  belongs_to :project, :inverse_of => :releases
  has_many :issues, :class_name => 'RbStory', :foreign_key => 'release_id', :dependent => :nullify

  validates_presence_of :project_id, :name, :release_start_date, :release_end_date
  validates_inclusion_of :status, :in => RELEASE_STATUSES
  validates_inclusion_of :sharing, :in => RELEASE_SHARINGS
  validates_length_of :name, :maximum => 64
  validate :dates_valid?

  scope :open, :conditions => {:status => 'open'}
  scope :closed, :conditions => {:status => 'closed'}
  scope :visible, lambda {|*args| { :include => :project,
                                    :conditions => Project.allowed_to_condition(args.first || User.current, :view_releases) } }


  include Backlogs::ActiveRecord::Attributes

  def to_s; name end

  def closed?
    status == 'closed'
  end

  def dates_valid?
    errors.add(:base, l(:error_release_end_after_start)) if self.release_start_date >= self.release_end_date if self.release_start_date and self.release_end_date
  end

  def stories #compat
    issues
  end

  # Returns current stories + stories previously scheduled for this release
  def stories_all_time
    missing_stories = RbStory.joins(:journals => :details).where(
            "(release_id != ? or release_id IS NULL) and
            journal_details.property ='attr' and
            journal_details.prop_key = 'release_id' and
            (journal_details.old_value = ? or journal_details.value = ?)",
            self.id,self.id.to_s,self.id.to_s).release_burndown_includes
    (issues.release_burndown_includes + missing_stories).uniq
  end

  #Return sprints that contain issues within this release
  def sprints
    RbSprint.where('id in (select distinct(fixed_version_id) from issues where release_id=?)', id).order('versions.effective_date')
  end

  # Return sprints closed within this release
  def closed_sprints
    sprints.where("versions.status = ?", "closed")
  end

  def stories_by_sprint
    order = Backlogs.setting[:sprint_sort_order] == 'desc' ? 'DESC' : 'ASC'
#return issues sorted into sprints. Obviously does not return issues which are not in a sprint
#unfortunately, group_by returns unsorted results.
    issues.where(:tracker_id => RbStory.trackers).joins(:fixed_version).includes(:fixed_version).order("versions.effective_date #{order}").group_by(&:fixed_version_id)
  end

  # The dates are:
  # start: first day of release
  # 1..n: a day after the nth sprint
  def days
    current_date = Time.now.to_date
    days_of_interest = Array.new
    days_of_interest << self.release_start_date.to_date
    self.sprints.each{|sprint|
      days_of_interest << sprint.effective_date.to_date
    }
    # Add current day if we are past last sprint end date and has open stories
    days_of_interest << Time.now.to_date if self.has_open_stories? and Time.now.to_date > days_of_interest[-1]
    return days_of_interest.uniq.sort
  end

  def last_closed_sprint_date
    RbSprint.where('id in (select distinct(fixed_version_id) from issues where release_id=?) and versions.status = ?', id, "closed").order("versions.effective_date DESC").first.effective_date.to_date unless closed_sprints.size == 0
  end

  def has_open_stories?
    stories.open.size > 0
  end

  def has_burndown?
    return self.stories.size > 0
  end

  def burndown
    # @cached_burndown is not the release_burndown_cache. This is just an instance variable to avoid
    # calculating the object more than once _per request_.
    # Nevertheless, @cached_burndown will be calculated at least once per request.
    #
    # On the other hand, rebuild of individual release_burndown_cache entries is triggered inside
    # each story when a story changes. Release_burndown_cache is not one atomic piece of data but
    # a set of fragments per story and therefore it does not need a logic similar to the sprint burndown cache.
    # If anything (dates, sprints, sprint status etc.) changes, the release burndown will ask just more
    # stories and thus the cache needs no touching.
    return nil if not self.has_burndown?
    @cached_burndown ||= ReleaseBurndown.new(self)
    return @cached_burndown
  end

  def today
    ReleaseBurndownDay.find(:first, :conditions => { :release_id => self, :day => Date.today })
  end

  def remaining_story_points #FIXME merge bohansen_release_chart removed this
    res = 0
    stories.open.each {|s| res += s.story_points if s.story_points}
    res
  end

  def allowed_sharings(user = User.current)
    RELEASE_SHARINGS.select do |s|
      if sharing == s
        true
      else
        case s
        when 'system'
          # Only admin users can set a systemwide sharing
          user.admin?
        when 'hierarchy', 'tree'
          # Only users allowed to manage versions of the root project can
          # set sharing to hierarchy or tree
          project.nil? || user.allowed_to?(:manage_versions, project.root)
        else
          true
        end
      end
    end
  end

  def shared_to_projects(scope_project)
    projects = []
    Project.visible.find(:all, :order => 'lft').each{|_project| #exhaustive search FIXME (pa sharing)
      projects << _project unless (_project.shared_releases.collect{|v| v.id} & [id]).empty?
    }
    projects
  end

  #migrate old date-based releases to relation-based
  def self.integrate_implicit_stories
    unless RbStory.trackers
      puts "Redmine not configured, skipping release migratinos"
      return
    end
    #each release from newest to oldest
    RbRelease.order('release_end_date desc').each do |release|
      if release.project.nil?
        # Release comes from deleted project before dependency was added.
        release.delete
      else
        release.project.versions.select{ |v| v.due_date && (v.due_date>=release.release_start_date && v.due_date<=release.release_end_date)
        }.each do |version|
          #each sprint that lies within the release
          version.fixed_issues.where('tracker_id in (?)', RbStory.trackers).each { |issue|
            #each issue in that version which is a story and does not belong to a release, yet
            if issue.release_id.nil?
              issue.release = release;
              issue.save!
            end
          }
        end #sprints
      end #releases
    end #if project.nil?
  end

end
