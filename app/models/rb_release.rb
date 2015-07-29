require 'date'
require 'linear_regression'

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
  attr_reader :lr_closed # linear regression closed
  attr_reader :lr_scope # linear regression scope

  private

  def calculate_burndown(release)
    @data[:offset_points] = []
    @data[:added_points] = []
    @data[:backlog_points] = []
    @data[:closed_points] = []

    baseline = [0] * @days.size

    series = Backlogs::MergedArray.new
    series.merge(:total_points => baseline.dup)
    series.merge(:added_points => baseline.dup)
    series.merge(:closed_points => baseline.dup)

    # Fetch stories of all time an find out which ones has missing cache entries
    # for any of the given days.
    release.stories_all_time.where(
            "( select count(c.day) from rb_release_burnchart_day_caches c
            where issues.id = c.issue_id AND
            c.release_id = ? AND c.day IN (?)) != ?",
            release.id, @days, @days.size).each{|s|
              s.update_release_burnchart_data(@days,release.id)
            }

    # Calculate total, added and closed points
    total = RbReleaseBurnchartDayCache.where("release_id = ? AND day IN (?)",release.id,@days)
              .order(:day).group(:day).sum(:total_points)
    added = RbReleaseBurnchartDayCache.where("release_id = ? AND day IN (?)",release.id,@days)
              .order(:day).group(:day).sum(:added_points)
    closed = RbReleaseBurnchartDayCache.where("release_id = ? AND day IN (?)",release.id,@days)
               .order(:day).group(:day).sum(:closed_points)

    # Series collected, now format data for jqplot
    # Slightly hacky formatting to get the correct view. Might change when this jqplot issue is 
    # sorted out:
    # See https://bitbucket.org/cleonello/jqplot/issue/181/nagative-values-in-stacked-bar-chart
    @data[:closed_points] = closed.values
    @data[:backlog_points] = total.values.each_with_index.map{|n,i|
      n - closed.values[i] - added.values[i] }
    @data[:added_points] = added.values
    @data[:total_points] = total.values

    # Keyfigures for later calculations
    @index_last_active = calc_index_before(release.last_active_sprint_date)
    @index_estimate_last = calc_index_before
    @last_total_points = @data[:total_points][@index_last_active] # notice total points utilize latest active sprint
    @last_closed_points = @data[:closed_points][@index_estimate_last] # whereas closed points does not look at ongoing sprints
    @last_points_left = @last_total_points - @last_closed_points
    @last_date = release.days[@index_estimate_last]
  end


  def calculate_trend
    @data[:trend_scope] = []
    @data[:trend_closed] = []

    return unless @last_points_left > 0
    return unless @index_estimate_last > 0
    avg_count = @index_estimate_last >= 3 ? 3 : @index_estimate_last
    index_estimate_first = @index_estimate_last - avg_count
    index_last_active_first = @index_last_active - avg_count

    @lr_closed = Backlogs::LinearRegression.new(@days[index_estimate_first..@index_estimate_last],
                                                @data[:closed_points][index_estimate_first..@index_estimate_last])

    @lr_scope = Backlogs::LinearRegression.new(@days[index_last_active_first..@index_last_active],
                                               @data[:total_points][index_last_active_first..@index_last_active])

    #Calculate trend end date (crossing trend_closed and trend_added)
    trend_cross_date = @lr_closed.crossing_date(@lr_scope)

    # Use active sprint closed points data to recalculate closed trendline if crossing is before current date
    if trend_cross_date.nil? or trend_cross_date < Time.now.to_date
      @lr_closed = Backlogs::LinearRegression.new(@days[index_estimate_first..@index_last_active],
                                                  @data[:closed_points][index_estimate_first..@index_last_active])
    end

    # Recalculate crossing date
    trend_cross_date = @lr_closed.crossing_date(@lr_scope)

    return if trend_cross_date.nil? # Still no crossing date in the future, nothing to show...


    trend_cross_days = (trend_cross_date - @last_date).to_i

    # Value for display in sidebar
    @trend_estimate_end_date = trend_cross_date

    estimate_days = 800
    # Add beginning and end dataset [sprint,points] for trendlines
    trendline_end_date = trend_cross_days.between?(1,730) ? trend_cross_date + 30 : @last_date + estimate_days

    @data[:trend_closed] = lr_closed.predict_line(trendline_end_date)
    @data[:trend_scope] = lr_scope.predict_line(trendline_end_date)
  end

  def calculate_planned
    @data[:planned] = []

    return unless @last_points_left > 0
    return unless @planned_velocity.is_a? Float
    return unless @planned_velocity > 0.0

    @data[:planned] << [@last_date, @last_closed_points]
    #FIXME add possibility to choose velocity per week, fortnight, month?
    @planned_estimate_end_date = @last_date + (@last_points_left / @planned_velocity * 30)
    @data[:planned] << [@planned_estimate_end_date, @data[:total_points][@index_estimate_last]]

  end

  # Calculate index in days array before last_date
  def calc_index_before(last_date = nil)
    date = last_date.nil? ? Time.now.to_date : last_date
    result = []
    result << 0
    @days.each_with_index{|d,i|
      result << i if d <= date
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
  has_many :rb_release_burnchart_day_cache, :dependent => :delete_all, :foreign_key => 'release_id'

  attr_accessible :project_id, :name, :release_start_date, :release_end_date, :status
  attr_accessible :project, :description, :planned_velocity, :sharing

  validates_presence_of :project_id, :name, :release_start_date, :release_end_date
  validates_inclusion_of :status, :in => RELEASE_STATUSES
  validates_inclusion_of :sharing, :in => RELEASE_SHARINGS
  validates_length_of :name, :maximum => 64
  validate :dates_valid?

  scope :open, -> {
    where(:status => 'open')
  }
  scope :closed, -> {
    where(:status => 'closed')
  }
  scope :visible, lambda {|*args| joins(:project).includes(:project).
                                    where(Project.allowed_to_condition(args.first || User.current, :view_releases)) }


  include Backlogs::ActiveRecord::Attributes

  def to_s; name end

  def closed?
    status == 'closed'
  end

  def dates_valid?
    errors.add(:base, "release_end_after_start") if self.release_start_date >= self.release_end_date if self.release_start_date and self.release_end_date
  end

  def stories #compat
    issues
  end

  # Returns current stories + stories previously scheduled for this release
  def stories_all_time
    RbStory.joins(:journals => :details).includes(:journals => :details).where(
            "(release_id = ?) OR (
            journal_details.property ='attr' and
            journal_details.prop_key = 'release_id' and
            (journal_details.old_value = ? or journal_details.value = ?))",
            self.id,self.id.to_s,self.id.to_s).release_burndown_includes
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
      days_of_interest << sprint.effective_date.to_date unless sprint.effective_date.nil?
    }
    # Add current day if we are past last sprint end date and has open stories
    days_of_interest << Time.now.to_date if self.has_open_stories? and Time.now.to_date > days_of_interest[-1]
    return days_of_interest.uniq.sort
  end

  def last_closed_sprint_date
    RbSprint.where('id in (select distinct(fixed_version_id) from issues where release_id=?) and versions.status = ?', id, "closed").order("versions.effective_date DESC").first.effective_date.to_date unless closed_sprints.size == 0
  end

  def last_active_sprint_date
    last_active_sprint = RbSprint.where('id in (select distinct(fixed_version_id) from issues where release_id=? and ? between sprint_start_date and effective_date)', id,Time.now.beginning_of_day).order("versions.effective_date DESC")
    return last_active_sprint.first.effective_date.to_date unless last_active_sprint.size == 0
  end

  def has_open_stories?
    stories.open.size > 0
  end

  def has_burndown?
    false #FIXME release burndown broken
    #return self.stories.size > 0
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
    ReleaseBurndownDay.where(release_id: self, day: Date.today).first
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
    @shared_projects ||=
      begin
        # Project used when fetching tree sharing
        r = self.project.root? ? self.project : self.project.root
        # Project used for other sharings
        p = self.project
        Project.visible.joins('LEFT OUTER JOIN releases ON releases.project_id = projects.id').
        includes(:releases).
          where("#{RbRelease.table_name}.id = #{id}" +
          " OR (#{Project.table_name}.status <> #{Project::STATUS_ARCHIVED} AND (" +
          " 'system' = ? " +
          " OR (#{Project.table_name}.lft >= #{r.lft} AND #{Project.table_name}.rgt <= #{r.rgt} AND ? = 'tree')" +
          " OR (#{Project.table_name}.lft > #{p.lft} AND #{Project.table_name}.rgt < #{p.rgt} AND ? IN ('hierarchy', 'descendants'))" +
          " OR (#{Project.table_name}.lft < #{p.lft} AND #{Project.table_name}.rgt > #{p.rgt} AND ? = 'hierarchy')" +
          "))",sharing,sharing,sharing,sharing).order('lft').distinct
      end
    @shared_projects
  end

  #FIXME Code should be moved to migration task and not require the real model-objects.
  #See "Using model in your migrations." on http://guides.rubyonrails.org/migrations.html.
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
              # Only update column, hence no callback functions executed which
              # might touch non-existing columns during migration.
              issue.update_column(:release_id,release.id)
            end
          }
        end #sprints
      end #releases
    end #if project.nil?
  end

end
