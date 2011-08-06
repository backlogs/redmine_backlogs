require 'date'

class Burndown
  def initialize(sprint, burn_direction)
    burn_direction = burn_direction || Setting.plugin_redmine_backlogs[:points_burn_direction]

    @sprint_id = sprint.id
    @days = sprint.days(:all)

    stories = sprint.stories | Journal.find(:all, :joins => :details,
                                            :conditions => ["journalized_type = 'Issue'
                                                            and property = 'attr' and prop_key = 'fixed_version_id'
                                                            and (value = ? or old_value = ?)", sprint.id, sprint.id]).collect{|j| j.journalized.becomes(RbStory) }

    data = stories.collect{|s| s.burndown(sprint) }
    if data.size == 0
      data = []
      [:points, :hours, :points_accepted, :points_resolved].each {|key| data[key] = [nil] * (@days.size + 1) }
    end

    @data = {}

    [:points, :hours, :points_accepted, :points_resolved].each {|key|
      @data[key] = data.collect{|d| d[key]}.transpose.collect{|d| d.compact.sum}
    }
    @data[:points_committed] = @data.delete(:points)
    @data[:hours_remaining] = @data.delete(:hours)

    @data[:hours_ideal] = (0 .. @days.size).collect{|i| (@data[:hours_remaining][0] / @days.size) * i}.reverse

    @data[:points_to_resolve] = @data[:points_committed].zip(@data[:points_resolved]).collect{|cr| cr[0] - cr[1]}
    @data[:points_to_accept] = @data[:points_committed].zip(@data[:points_accepted]).collect{|cr| cr[0] - cr[1]}

    @data[:points_required_burn_rate] = @data[:points_to_resolve].collect{|p| Float(p)}.enum_for(:each_with_index).collect{|p, i| @days.size == i ? p : p / (@days.size - i)}
    @data[:hours_required_burn_rate] = @data[:hours_remaining].enum_for(:each_with_index).collect{|h, i| @days.size == i ? h : h / (@days.size - i)}

    if burn_direction == 'up'
      @data.delete(:points_to_resolve)
      @data.delete(:points_to_accept)
    else
      @data.delete(:points_resolved)
      @data.delete(:points_accepted)
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
    raise "No burndown data series '#{i}', available: #{@data.keys.inspect}" unless @data[i]
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

    def days(cutoff, issue=nil)
      return nil unless has_burndown

      case cutoff
        when :active
          d = (self.sprint_start_date .. [self.effective_date, Date.today].min)
        when :all
          d = (self.sprint_start_date .. self.effective_date)
        else
          raise "Unexpected day range '#{cutoff.inspect}'"
      end

      # assumes mon-fri are working days, sat-sun are not. this
      # assumption is not globally right, we need to make this configurable.
      d = d.select {|d| (d.wday > 0 and d.wday < 6) }
      return d unless issue

      first = {:first => :first}
      day = 60 * 60 * 24
      dates = d.collect{|dy|
        dy = Time.local(dy.year, dy.mon, dy.mday, 0, 0, 0)
        dy = nil if issue.created_on >= dy + day
        dy = (first.delete(:first) || dy) if dy
        dy = nil if dy && issue.historic(dy, 'fixed_version_id') != self.id
        dy = nil if dy && IssueStatus.find(issue.historic(dy, 'status_id')).is_closed?
        dy
      }
      dates << (dates[-1] ? :last : nil)
      return dates
    end

    def eta
        return nil if ! self.start_date

        dpp = self.project.scrum_statistics.info[:average_days_per_point]
        return nil if !dpp

        # assume 5 out of 7 are working days
        return self.start_date + Integer(self.points * dpp * 7.0/5)
    end

    def has_burndown
        return !!(self.effective_date and self.sprint_start_date)
    end

    def activity
        bd = self.burndown('up')
        return false if !bd

        # assume a sprint is active if it's only 2 days old
        return true if bd[:hours_remaining].compact.size <= 2

        return Issue.exists?(['fixed_version_id = ? and ((updated_on between ? and ?) or (created_on between ? and ?))', self.id, -2.days.from_now, Time.now, -2.days.from_now, Time.now])
    end

    def burndown(burn_direction = nil)
        return nil if not self.has_burndown
        @cached_burndown ||= Burndown.new(self, burn_direction)
        return @cached_burndown
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
