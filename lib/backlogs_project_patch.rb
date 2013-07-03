require_dependency 'project'

module Backlogs
  class Statistics
    def initialize(project)
      @project = project
      @statistics = {:succeeded => [], :failed => [], :values => {}}

      @active_sprint = @project.active_sprint
      @past_sprints = RbSprint.find(:all,
        :conditions => ["project_id = ? and not(effective_date is null or sprint_start_date is null) and effective_date < ?", @project.id, Date.today],
        :order => "effective_date desc",
        :limit => 5).select(&:has_burndown?)
      @all_sprints = (@past_sprints + [@active_sprint]).compact

      @all_sprints.each{|sprint| sprint.burndown.direction = :up }
      days = @past_sprints.collect{|s| s.days.size}.sum
      if days != 0
        @points_per_day = @past_sprints.collect{|s| s.burndown.cached_data[:points_committed][0]}.compact.sum / days #FIXME this is very expensive
      end

      if @all_sprints.size != 0
        @velocity = @past_sprints.collect{|sprint| sprint.burndown.cached_data[:points_accepted][-1].to_f}
        @velocity_stddev = stddev(@velocity)
      end

      spent_hours = @past_sprints.collect{|sprint| sprint.spent_hours}
      @spent_hours_per_point = spent_hours.sum / @velocity.sum unless spent_hours.nil? || @velocity.nil? || @velocity.sum == 0

      @product_backlog = RbStory.product_backlog(@project, 10)

      hours_per_point = []
      @all_sprints.each {|sprint|
        hours = sprint.burndown.cached_data[:hours_remaining][0].to_f
        next if hours == 0.0
        hours_per_point << sprint.burndown.cached_data[:points_committed][0].to_f / hours
      }

      @hours_per_point_stddev = stddev(hours_per_point)
      @hours_per_point = hours_per_point.sum.to_f / hours_per_point.size unless hours_per_point.size == 0

      Statistics.active_tests.sort.each{|m|
        r = send(m.intern)
        next if r.nil? # this test deems itself irrelevant
        @statistics[r ? :succeeded : :failed] <<
          (m.to_s.gsub(/^test_/, '') + (r ? '' : '_failed'))
      }
      Statistics.stats.sort.each{|m|
        v = send(m.intern)
        @statistics[:values][m.to_s.gsub(/^stat_/, '')] = v unless v.nil? || (v.respond_to?(:"nan?") && v.nan?) || (v.respond_to?(:"infinite?") && v.infinite?)
      }

      if @statistics[:succeeded].size == 0 && @statistics[:failed].size == 0
        @score = 100 # ?
      else
        @score = (@statistics[:succeeded].size * 100) / (@statistics[:succeeded].size + @statistics[:failed].size)
      end
    end

    attr_reader :statistics, :score
    attr_reader :active_sprint, :past_sprints
    attr_reader :hours_per_point
    attr_reader :spent_hours_per_point

    def stddev(values)
      median = values.sum / values.size.to_f
      variance = 1.0 / (values.size * values.inject(0){|acc, v| acc + (v-median)**2})
      return Math.sqrt(variance)
    end

    def self.available
      return Statistics.instance_methods.select{|m| m =~ /^test_/}.collect{|m| m.split('_', 2).collect{|s| s.intern}}
    end

    def self.active_tests
      # test this!
      return Statistics.instance_methods.select{|m| m =~ /^test_/}.reject{|m| Backlogs.setting["disable_stats_#{m}".intern] }
    end

    def self.active
      return Statistics.active_tests.collect{|m| m.split('_', 2).collect{|s| s.intern}}
    end

    def self.stats
      return Statistics.instance_methods.select{|m| m =~ /^stat_/}
    end

    def info_no_active_sprint
      return !@active_sprint
    end

    def test_product_backlog_filled
      return (@project.status != Project::STATUS_ACTIVE || @product_backlog.length != 0)
    end

    def test_product_backlog_sized
      return !@product_backlog.detect{|s| s.story_points.blank? }
    end

    def test_sprints_sized
      return !Issue.exists?(["story_points is null and fixed_version_id in (?) and tracker_id in (?)", @all_sprints.collect{|s| s.id}, RbStory.trackers])
    end

    def test_sprints_estimated
      return !Issue.exists?(["estimated_hours is null and fixed_version_id in (?) and tracker_id = ?", @all_sprints.collect{|s| s.id}, RbTask.tracker])
    end

    def test_sprint_notes_available
      return !@past_sprints.detect{|s| !s.has_wiki_page}
    end

    def test_active
      return (@project.status != Project::STATUS_ACTIVE || (@active_sprint && @active_sprint.activity))
    end

    def test_yield
      accepted = []
      @past_sprints.each {|sprint|
        bd = sprint.burndown
        bd.direction = :up
        c = bd.cached_data[:points_committed][-1]
        a = bd.cached_data[:points_accepted][-1]
        next unless c && a && c != 0

        accepted << [(a * 100.0) / c, 100.0].min
      }
      return false if accepted == []
      return (stddev(accepted) < 10) # magic number
    end

    def test_committed_velocity_stable
      return (@velocity_stddev && @velocity_stddev < 4) # magic number!
    end

    def test_sizing_consistent
      return (@hours_per_point_stddev < 4) # magic number
    end

    def stat_sprints
      return @past_sprints.size
    end

    def stat_velocity
      return nil unless @velocity && @velocity.size > 0
      return @velocity.sum / @velocity.size
    end

    def stat_velocity_stddev
      return @velocity_stddev unless @velocity_stddev.is_a? Float
      return '%.2f' % @velocity_stddev      
    end

    def stat_sizing_stddev
      return @hours_per_point_stddev unless @hours_per_point_stddev.is_a? Float
      return '%.2f' % @hours_per_point_stddev
    end

    def stat_hours_per_point
      return @hours_per_point unless @hours_per_point.is_a? Float
      return '%.2f' % @hours_per_point
    end

    def stat_spent_hours_per_point
      return nil unless @spent_hours_per_point
      return '%.2f' % @spent_hours_per_point
    end
  end

  module ProjectPatch
    def self.included(base) # :nodoc:
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)

      base.class_eval do
        unloadable
        has_many :releases, :class_name => 'RbRelease', :inverse_of => :project, :dependent => :destroy, :order => "#{RbRelease.table_name}.release_start_date DESC, #{RbRelease.table_name}.name DESC"
        include Backlogs::ActiveRecord::Attributes
      end
    end

    module ClassMethods
    end

    module InstanceMethods

      def scrum_statistics
        ## pretty expensive to compute, so if we're calling this multiple times, return the cached results
        @scrum_statistics ||= Backlogs::Statistics.new(self)
      end

      def rb_project_settings
        @project_settings ||= RbProjectSettings.first(:conditions => ["project_id = ?", self.id])
        unless @project_settings
          @project_settings = RbProjectSettings.new( :project_id => self.id)
          @project_settings.save
        end
        @project_settings
      end

      def projects_in_shared_product_backlog
        #sharing off: only the product itself is in the product backlog
        #sharing on: subtree is included in the product backlog
        if Backlogs.setting[:sharing_enabled] and self.rb_project_settings.show_stories_from_subprojects
          self.self_and_descendants.visible.active
        else
          [self]
        end
        #TODO have an explicit association map which project shares its issues into other product backlogs
      end

      #return sprints which are 
      # 1. open in project,
      # 2. share to project, 
      # 3. share to project but are scoped to project and subprojects
      #depending on sharing mode
      def open_shared_sprints
        if Backlogs.setting[:sharing_enabled]
          order = Backlogs.setting[:sprint_sort_order] == 'desc' ? 'DESC' : 'ASC'
          shared_versions.visible.scoped(:conditions => {:status => ['open', 'locked']}, :order => "sprint_start_date #{order}, effective_date #{order}").collect{|v| v.becomes(RbSprint) }
        else #no backlog sharing
          RbSprint.open_sprints(self)
        end 
      end

      #depending on sharing mode
      def closed_shared_sprints
        if Backlogs.setting[:sharing_enabled]
          order = Backlogs.setting[:sprint_sort_order] == 'desc' ? 'DESC' : 'ASC'
          shared_versions.visible.scoped(:conditions => {:status => ['closed']}, :order => "sprint_start_date #{order}, effective_date #{order}").collect{|v| v.becomes(RbSprint) }
        else #no backlog sharing
          RbSprint.closed_sprints(self)
        end
      end

      def active_sprint
        @active_sprint ||= RbSprint.find(:first, :conditions => [
          "project_id = ? and status = 'open' and not (sprint_start_date is null or effective_date is null) and ? between sprint_start_date and effective_date",
          self.id, (Time.zone ? Time.zone : Time).now.beginning_of_day
        ])
      end

      def open_releases_by_date
        order = Backlogs.setting[:sprint_sort_order] == 'desc' ? 'DESC' : 'ASC'
        (Backlogs.setting[:sharing_enabled] ? shared_releases : releases).
          visible.open.
          order("#{RbRelease.table_name}.release_start_date #{order}, #{RbRelease.table_name}.release_end_date #{order}")
      end

      def closed_releases_by_date
        order = Backlogs.setting[:sprint_sort_order] == 'desc' ? 'DESC' : 'ASC'
        (Backlogs.setting[:sharing_enabled] ? shared_releases : releases).
          visible.closed.
          order("#{RbRelease.table_name}.release_start_date #{order}, #{RbRelease.table_name}.release_end_date #{order}")
      end

      def shared_releases
        if new_record?
          RbRelease.scoped(:include => :project,
                       :conditions => "#{Project.table_name}.status <> #{Project::STATUS_ARCHIVED} AND #{RbRelease.table_name}.sharing = 'system'")
        else
          @shared_releases ||= begin
            r = root? ? self : root
            RbRelease.scoped(:include => :project,
                         :conditions => "#{Project.table_name}.id = #{id}" +
              " OR (#{Project.table_name}.status <> #{Project::STATUS_ARCHIVED} AND (" +
                    " #{RbRelease.table_name}.sharing = 'system'" +
              " OR (#{Project.table_name}.lft >= #{r.lft} AND #{Project.table_name}.rgt <= #{r.rgt} AND #{RbRelease.table_name}.sharing = 'tree')" +
              " OR (#{Project.table_name}.lft < #{lft} AND #{Project.table_name}.rgt > #{rgt} AND #{RbRelease.table_name}.sharing IN ('hierarchy', 'descendants'))" +
              " OR (#{Project.table_name}.lft > #{lft} AND #{Project.table_name}.rgt < #{rgt} AND #{RbRelease.table_name}.sharing = 'hierarchy')" +
              "))")
          end
        end
      end

    end
  end
end

Project.send(:include, Backlogs::ProjectPatch) unless Project.included_modules.include? Backlogs::ProjectPatch
