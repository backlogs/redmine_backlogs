require 'date'

class Burndown
  def initialize(sprint, direction)
    @direction = direction
    @sprint_id = sprint.id
    @days = sprint.days(:all)

    stories = sprint.stories | Journal.find(:all, :joins => :details,
                        :conditions => ["journalized_type = 'Issue'
                              and property = 'attr' and prop_key = 'fixed_version_id'
                              and (value = ? or old_value = ?)", sprint.id.to_s, sprint.id.to_s]).collect{|j| j.journalized.becomes(RbStory) }

    baseline = [0] * (sprint.days(:active).size + 1)
    baseline += [nil] * (1 + (@days.size - baseline.size))

    series = Backlogs::MergedArray.new
    series.merge(:hours => baseline.dup)
    series.merge(:points => baseline.dup)
    series.merge(:points_resolved => baseline.dup)
    series.merge(:points_accepted => baseline.dup)

    stories.each { |story| series.add(story.burndown(sprint)) }

    series.merge(:to_resolve => series.collect{|r| r.points && r.points_resolved ? r.points - r.points_resolved : nil})
    series.merge(:to_accept => series.collect{|a| a.points && a.points_accepted ? a.points - a.points_accepted : nil})

    series.merge(:days_left => (0..@days.size).collect{|d| @days.size - d})

    @data = {}

    @data[:points_committed] = series.collect{|s| s.points }
    @data[:hours_remaining] = series.collect{|s| s.hours }
    @data[:points_accepted] = series.collect{|s| s.points_accepted }
    @data[:points_resolved] = series.collect{|s| s.points_resolved }
    @data[:points_to_resolve] = series.collect{|s| s.to_resolve }
    @data[:points_to_accept] = series.collect{|s| s.to_accept }

    if series[0].hours
      @data[:hours_ideal] = (0 .. @days.size).collect{|i| (series[0].hours / @days.size) * i }.reverse
    else
      @data[:hours_ideal] = [nil] * @days.size
    end

    @data[:points_required_burn_rate] = series.collect{|r| r.to_resolve ? Float(r.to_resolve) / (r.days_left == 0 ? 1 : r.days_left) : nil }
    @data[:hours_required_burn_rate] = series.collect{|r| r.hours ? Float(r.hours) / (r.days_left == 0 ? 1 : r.days_left) : nil }

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

    max = {'hours' => nil, 'points' => nil}
    @data.keys.each{|series|
      units = series.to_s.gsub(/_.*/, '')
      next unless ['points', 'hours'].include?(units)
      max[units] = ([max[units]] + @data[series]).compact.max
    }

    @data[:max_points] = max['points']
    @data[:max_hours] = max['hours']
  end

  def [](i)
    i = i.intern if i.is_a?(String)
    raise "No burn#{@direction} data series '#{i}', available: #{@data.keys.inspect}" unless @data[i]
    return @data[i]
  end

  def series(remove_empty = true)
    @series ||= {}
    return @series[remove_empty] if @series[remove_empty]

    @series[remove_empty] = @data.keys.collect{|k| k.to_s}.select{|k| k =~ /^(points|hours)_/}.sort
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
    errors.add_to_base("Sprint cannot end before it starts") if self.effective_date && self.sprint_start_date && self.sprint_start_date >= self.effective_date
  end

  named_scope :open_sprints, lambda { |project|
    {
      :order => 'sprint_start_date ASC, effective_date ASC',
      :conditions => [ "status = 'open' and project_id = ?", project.id ]
    }
  }

  #TIB ajout du named_scope :closed_sprints
  named_scope :closed_sprints, lambda { |project|
    {
       :order => 'sprint_start_date ASC, effective_date ASC',
       :conditions => [ "status = 'closed' and project_id = ?", project.id ]
    }
  }

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

    template = Setting.plugin_redmine_backlogs[:wiki_template]
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

  def days(cutoff)
    return nil unless self.effective_date && self.sprint_start_date

    case cutoff
    when :active
      d = (self.sprint_start_date .. [self.effective_date, Date.today].min)
    when :all
      d = (self.sprint_start_date .. self.effective_date)
    else
      raise "Unexpected day range '#{cutoff.inspect}'"
    end

    if Setting.plugin_redmine_backlogs[:include_sat_and_sun]
      return d.to_a
    else
      # mon-fri are working days, sat-sun are not
      return d.select {|d| (d.wday > 0 and d.wday < 6) }
    end
  end

  def eta
    return nil if ! self.start_date

    dpp = self.project.scrum_statistics.info[:average_days_per_point]
    return nil if !dpp

    derived_days = if Setting.plugin_redmine_backlogs[:include_sat_and_sun]
                     Integer(self.points * dpp)
                   else
                     # 5 out of 7 are working days
                     Integer(self.points * dpp * 7.0/5)
                   end
    return self.start_date + derived_days
  end

  def has_burndown?
    return (days(:active) || []).size != 0
  end

  def activity
    bd = self.burndown('up')
    return false if !bd

    # assume a sprint is active if it's only 2 days old
    return true if bd[:hours_remaining].compact.size <= 2

    return Issue.exists?(['fixed_version_id = ? and ((updated_on between ? and ?) or (created_on between ? and ?))', self.id, -2.days.from_now, Time.now, -2.days.from_now, Time.now])
  end

  def burndown(direction=nil)
    return nil if not self.has_burndown? || !self.is_story?

    direction ||= Setting.plugin_redmine_backlogs[:points_burn_direction]
    direction = 'down' if direction != 'up'

    @burndown ||= {'up' => nil, 'down' => nil}
    @burndown[direction] ||= Burndown.new(self, direction)
    return @burndown[direction]
  end

  def impediments
    return Issue.find(:all, 
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
