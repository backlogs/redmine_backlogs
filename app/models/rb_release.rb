require 'date'

class ReleaseBurndown
  def initialize(release)
#    @days = release.days
    @release_id = release.id
    @project = release.project

    #initialize empty release
    @data = {}
    @data[:added_points] = []
    @data[:added_points_pos] = []
    @data[:backlog_points] = []
    @data[:closed_points] = []
    @data[:trend_added] = []
    @data[:trend_closed] = []

    # Select sprints within release period. They need not to be closed.
    sprints = release.sprints
    return if sprints.nil? || sprints.size == 0

    baseline = [0] * (sprints.size + 1)

    series = Backlogs::MergedArray.new
    series.merge(:backlog_points => baseline.dup)
    series.merge(:added_points => baseline.dup)
    series.merge(:closed_points => baseline.dup)

#TODO Caching
#TODO Maybe utilize/extend sprint burndown data?
#TODO Stories continued over several sprints (by duplicating) should not show up as added
#TODO Likewise stories split from inital epics should not show up as added

    # Go through each story in the backlog
    release.stories.each{ |story|
      series.add(story.release_burndown_data(sprints))
    }

    # Series collected, now format data for jqplot
    # Slightly hacky formatting to get the correct view. Might change when this jqplot issue is 
    # sorted out:
    # See https://bitbucket.org/cleonello/jqplot/issue/181/nagative-values-in-stacked-bar-chart
#TODO Maybe move jqplot format stuff to releaseburndown view?
    @data[:added_points] = series.collect{ |s| -1 * s.added_points }
    @data[:added_points_pos] = series.collect{ |s| s.backlog_points >= 0 ? s.added_points : s.added_points + s.backlog_points }
    @data[:backlog_points] = series.collect{ |s| s.backlog_points >= 0 ? s.backlog_points : 0 }
    @data[:closed_points] = series.series(:closed_points)


    # Forecast (probably just as good as the weather forecast...)
#TODO Move forecast to RbRelease?
    @data[:trend_closed] = Array.new
    @data[:trend_added] = Array.new
    avg_count = 3
    if release.closed_sprints.size >= avg_count
      avg_added = (@data[:added_points][-1] - @data[:added_points][-avg_count]) / avg_count
      avg_closed = @data[:closed_points][-avg_count..-1].inject(0){|sum,p| sum += p} / avg_count
      current_backlog = @data[:added_points][-1] + @data[:added_points_pos][-1] + @data[:backlog_points][-1]
      current_added = @data[:added_points][-1]
      current_sprints = @data[:closed_points].size

      # Add beginning and end dataset [sprint,points] for trendlines
      @data[:trend_closed] << [current_sprints, current_backlog]
      @data[:trend_closed] << [current_sprints + 10, current_backlog - avg_closed * 10]
      @data[:trend_added] << [current_sprints, current_added]
      @data[:trend_added] << [current_sprints + 10, current_added + avg_added * 10]

    end

#TODO Estimate sprints left
    sprints_left = [0] * 10

    # Extend other series with empty datapoints up to the estimated number of sprints
    # to format plot correctly
    @data[:added_points].concat sprints_left.dup
    @data[:added_points_pos].concat sprints_left.dup
    @data[:backlog_points].concat sprints_left.dup
    @data[:closed_points].concat sprints_left.dup
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

  attr_reader :days
  attr_reader :release_id
  attr_reader :max

  attr_reader :remaining_story_points
  attr_reader :ideal
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

  #Return sprints that contain issues within this release
  def sprints
    RbSprint.where('id in (select distinct(fixed_version_id) from issues where release_id=?)', id)
  end

  # Return sprints closed within this release
  def closed_sprints
    sprints.where("versions.status = ?", "closed")
  end

  def stories_by_sprint
    order = Backlogs.setting[:sprint_sort_order] == 'desc' ? 'DESC' : 'ASC'
#return issues sorted into sprints. Obviously does not return issues which are not in a sprint
#unfortunately, group_by returns unsorted results.
    issues.joins(:fixed_version).includes(:fixed_version).order("versions.effective_date #{order}").group_by(&:fixed_version_id)
  end

  def days(cutoff = nil)
    # assumes mon-fri are working days, sat-sun are not. this
    # assumption is not globally right, we need to make this configurable.
    cutoff = self.release_end_date if cutoff.nil?
    workdays(self.release_start_date, cutoff)
  end

  def has_burndown?
#merge: is it neccessary to have closed sprints for burndown? I'd like to see it immediately
    return !!(self.release_start_date and self.release_end_date && !self.closed_sprints.nil?)
  end

  def burndown
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
