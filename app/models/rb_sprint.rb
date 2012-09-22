require 'date'

class Burndown
  def initialize(sprint, direction)
    @direction = direction
    @sprint_id = sprint.id

    @days = sprint.days
    @data = {}
    [:hours_remaining, :points_committed, :points_accepted, :points_resolved].each{|k| @data[k] = [nil] * @days.size }
    statuses = RbIssueHistory.statuses
    RbStory.find(:all, :conditions => ['id in (?)', sprint.history.issues]).each{|story|
      bd = story.burndown(sprint, statuses)
      next unless bd
      bd.each_pair {|k, data|
        puts "#{k.inspect} #{data.inspect}"
        data.each_with_index{|d, i|
          next unless d
          @data[k][i] ||= 0
          @data[k][i] += d
        }
      }
    }
    @data.keys.each{|k| @data[k] = @data[k].collect{|v| v == :nil ? nil : v} }

    @data[:ideal] = (0..@days.size - 1).to_a.reverse
    [[:points_to_resolve, :points_resolved], [:points_to_accept, :points_accepted]].each{|todo|
      tgt, src = *todo
      @data[tgt] = (0..@days.size - 1).to_a.collect{|i| @data[:points_committed][i] && @data[src][i] ? @data[:points_committed][i] - @data[src][i] : nil }
    }
    [[:points_required_burn_rate, :points_to_resolve], [:hours_required_burn_rate, :hours_remaining]].each{|todo|
      tgt, src = *todo
      @data[tgt] = (0..@days.size - 1).to_a.collect{|i| @data[src][i] ? Float(@data[src][i]) / (@data[:ideal][i] == 0 ? 1 : @data[:ideal][i]) : nil }
    }

    case direction
      when 'up'
        @data.delete(:points_to_resolve)
        @data.delete(:points_to_accept)
      when 'down'
        @data.delete(:points_resolved)
        @data.delete(:points_accepted)
      else
        raise "Unexpected burn direction #{direction.inspect}"
    end
  end

  def [](i)
    i = i.intern if i.is_a?(String)
    raise "No burn#{@direction} data series '#{i}', available: #{@data.keys.inspect}" unless @data[i]
    return @data[i]
  end

  def series(remove_empty = true)
    @series ||= {}
    return @series[remove_empty] if @series[remove_empty]

    @series[remove_empty] = @data.keys.collect{|k| k.to_s}.sort
    return @series[remove_empty] unless remove_empty

    # delete :points_committed if flatline
    @series[remove_empty].delete('points_committed') if @data[:points_committed].uniq.compact.size < 1

    # delete any series that is flat-line 0/nil
    @series[remove_empty].each {|k|
      @series[remove_empty].delete(k) if k != 'points_committed' && @data[k.intern].collect{|d| d.to_f }.uniq == [0.0]
    }
    return @series[remove_empty]
  end

  attr_reader :days
  attr_reader :sprint_id
  attr_reader :data
  attr_reader :direction
end

class RbSprint < Version
  unloadable

  validate :start_and_end_dates

  def start_and_end_dates
    errors.add(:base, "sprint_end_before_start") if self.effective_date && self.sprint_start_date && self.sprint_start_date >= self.effective_date
  end

  def self.rb_scope(symbol, func)
    if Rails::VERSION::MAJOR < 3
      named_scope symbol, func
    else
      scope symbol, func
    end
  end

  rb_scope :open_sprints, lambda { |project|
    {
      :order => "CASE sprint_start_date WHEN NULL THEN 1 ELSE 0 END ASC,
                 sprint_start_date ASC,
                 CASE effective_date WHEN NULL THEN 1 ELSE 0 END ASC,
                 effective_date ASC",
      :conditions => [ "status = 'open' and project_id = ?", project.id ] #FIXME locked, too?
    }
  }

  #TIB ajout du scope :closed_sprints
  rb_scope :closed_sprints, lambda { |project|
    {
      :order => "CASE sprint_start_date WHEN NULL THEN 1 ELSE 0 END ASC,
                 sprint_start_date ASC,
                 CASE effective_date WHEN NULL THEN 1 ELSE 0 END ASC,
                 effective_date ASC",
      :conditions => [ "status = 'closed' and project_id = ?", project.id ]
    }
  }

  #depending on sharing mode
  #return array of projects where this sprint is visible
  def shared_to_projects(scope_project)
    projects = []
    Project.visible.find(:all, :order => 'lft').each{|_project| #exhaustive search FIXME (pa sharing)
      projects << _project unless (_project.shared_versions.collect{|v| v.id} & [id]).empty?
    }
    projects
  end

  def stories
    return RbStory.sprint_backlog(self)
  end

  def points
    return stories.inject(0){|sum, story| sum + story.story_points.to_i}
  end

  def has_wiki_page
    return false if wiki_page_title.blank?

    page = project.wiki.find_page(self.wiki_page_title)
    return false if !page

    template = find_wiki_template
    return false if template && page.text == template.text

    return true
  end

  def find_wiki_template
    projects = [self.project] + self.project.ancestors

    template = Backlogs.setting[:wiki_template]
    if template =~ /:/
      p, template = *template.split(':', 2)
      projects << Project.find(p)
    end

    projects.compact!

    projects.each{|p|
      next unless p.wiki
      t = p.wiki.find_page(template)
      return t if t
    }
    return nil
  end

  def wiki_page
    if ! project.wiki
      return ''
    end

    self.update_attribute(:wiki_page_title, Wiki.titleize(self.name)) if wiki_page_title.blank?

    page = project.wiki.find_page(self.wiki_page_title)
    if !page
      template = find_wiki_template
      if template
      page = WikiPage.new(:wiki => project.wiki, :title => self.wiki_page_title)
      page.content = WikiContent.new
      page.content.text = "h1. #{self.name}\n\n#{template.text}"
      page.save!
      end
    end

    return wiki_page_title
  end

  def days
    return nil unless self.sprint_start_date && self.effective_date
    (self.sprint_start_date .. self.effective_date + 1).to_a.select{|d| Backlogs.setting[:include_sat_and_sun] || !(d.saturday? || d.sunday?)}
  end

  def eta
    return nil if ! self.sprint_start_date

    dpp = self.project.scrum_statistics.info[:average_days_per_point]
    return nil if !dpp

    derived_days = if Backlogs.setting[:include_sat_and_sun]
                     Integer(self.points * dpp)
                   else
                     # 5 out of 7 are working days
                     Integer(self.points * dpp * 7.0/5)
                   end
    return self.sprint_start_date + derived_days
  end

  def has_burndown?
    return (self.days || []).size != 0
  end

  def activity
    bd = self.burndown('up')
    return false if !bd

    # assume a sprint is active if it's only 2 days old
    return true if bd[:hours_remaining].compact.size <= 2

    return Issue.exists?(['fixed_version_id = ? and ((updated_on between ? and ?) or (created_on between ? and ?))', self.id, -2.days.from_now, Time.now, -2.days.from_now, Time.now])
  end

  def burndown(direction=nil)
    return nil if not self.has_burndown?

    direction ||= Backlogs.setting[:points_burn_direction]
    direction = 'down' if direction != 'up'

    @burndown ||= {'up' => nil, 'down' => nil}
    @burndown[direction] ||= Burndown.new(self, direction)
    return @burndown[direction]
  end

  def impediments
    @impediments ||= Issue.find(:all,
      :conditions => ["id in (
              select issue_from_id
              from issue_relations ir
              join issues blocked
                on blocked.id = ir.issue_to_id
                and blocked.tracker_id in (?)
                and blocked.fixed_version_id = (?)
              where ir.relation_type = 'blocks'
              )",
            RbStory.trackers + [RbTask.tracker],
            self.id]
      ) #.sort {|a,b| a.closed? == b.closed? ?  a.updated_on <=> b.updated_on : (a.closed? ? 1 : -1) }
  end

end
