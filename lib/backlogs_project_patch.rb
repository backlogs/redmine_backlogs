require_dependency 'project'

module Backlogs
  class Statistics
    def initialize(project)
      @project = project
      @statistics = {:succeeded => [], :failed => [], :values => {}}

      @active_sprint = RbSprint.find(:first, :conditions => ["project_id = ? and status = 'open' and ? between sprint_start_date and effective_date", @project.id, Date.today])
      @past_sprints = RbSprint.find(:all,
        :conditions => ["project_id = ? and not(effective_date is null or sprint_start_date is null) and effective_date < ?", @project.id, Date.today],
        :order => "effective_date desc",
        :limit => 5).select(&:has_burndown?)

      @points_per_day = @past_sprints.collect{|s| s.burndown('up')[:points_committed][0]}.compact.sum / @past_sprints.collect{|s| s.days(:all).size}.compact.sum if @past_sprints.size > 0

      @all_sprints = (@past_sprints + [@active_sprint]).compact

      if @all_sprints.size != 0
        @velocity = @past_sprints.collect{|sprint| sprint.burndown('up')[:points_accepted][-1]}
        @velocity_stddev = stddev(@velocity)
      end

      @product_backlog = RbStory.product_backlog(@project, 10)

      hours_per_point = []
      @all_sprints.each {|sprint|
        sprint.stories.each {|story|
          bd = story.burndown
          h = bd[:hours][0]
          p = bd[:points][0]
          next unless h && p && p != 0
          hours_per_point << (h / p.to_f)
        }
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
        @statistics[:values][m.to_s.gsub(/^stat_/, '')] =
          v unless
                   v.nil? ||
                   (v.respond_to?(:"nan?") && v.nan?) ||
                   (v.respond_to?(:"infinite?") && v.infinite?)
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
        bd = sprint.burndown('up')
        c = bd[:points_committed][-1]
        a = bd[:points_accepted][-1]
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
      return @velocity_stddev
    end

    def stat_sizing_stddev
      return @hours_per_point_stddev
    end

    def stat_hours_per_point
      return @hours_per_point
    end
  end

  module ProjectPatch
    def self.included(base) # :nodoc:
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)
    end
    
    module ClassMethods
    end
    
    module InstanceMethods
    
      def scrum_statistics
        ## pretty expensive to compute, so if we're calling this multiple times, return the cached results
        @scrum_statistics = Rails.cache.fetch("Project(#{self.id}).scrum_statistics", {:expires_in => 4.hours}) { Backlogs::Statistics.new(self) } unless @scrum_statistics
    
        return @scrum_statistics
      end
    
    end
  end
end

Project.send(:include, Backlogs::ProjectPatch) unless Project.included_modules.include? Backlogs::ProjectPatch
