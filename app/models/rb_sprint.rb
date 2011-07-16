require 'date'

class Burndown
  def initialize(sprint, burn_direction = nil)
    burn_direction = burn_direction || Setting.plugin_redmine_backlogs[:points_burn_direction]

    @days = sprint.days
    @sprint_id = sprint.id

    now = Time.now
    days = @days.collect{|d| Time.local(d.year, d.mon, d.mday, 0, 0, 0) }.select{|d| d <= now }
    days[0] = :first
    days << :last

    data = sprint.stories.collect{|s| s.burndown(days) }

    filler = [nil] * ((@days.size + 1) - days.size)

    alldays = (0 .. @days.size)
    ndays = days.size
    days = (0..days.size)

    @data = {}

    @data[:points_committed] = days.collect{|i| data.collect{|s| s[:points][i] }.compact.inject(0) {|total, p| total + p}} + filler
    @data[:hours_remaining] = days.collect{|i| data.collect{|s| s[:hours][i] }.compact.inject(0) {|total, h| total + h}} + filler
    @data[:hours_ideal] = alldays.collect{|i| (@data[:hours_remaining][0] / ndays) * i}.reverse

    @data[:points_accepted] = days.collect{|i| data.collect{|s| s[:points_accepted][i] }.compact.inject(0) {|total, p| total + p}} + filler
    @data[:points_resolved] = days.collect{|i| data.collect{|s| s[:points_resolved][i] }.compact.inject(0) {|total, p| total + p}} + filler

    @data[:points_to_resolve] = days.collect{|i| @data[:points_committed][i] - @data[:points_resolved][i] } + filler
    @data[:points_to_accept] = days.collect{|i| @data[:points_accepted][i] - @data[:points_resolved][i] } + filler

    @data[:points_required_burn_rate] = days.collect{|i| Float(@data[:points_to_resolve][i]) / ((ndays - i) + 0.01) } + filler
    @data[:hours_required_burn_rate] = days.collect{|i| Float(@data[:hours_remaining][i]) / ((ndays - i) + 0.01) } + filler

    if burn_direction == 'down'
      @data.delete(:points_to_resolve)
      @data.delete(:points_to_accept)
    else
      @data.delete(:points_resolved)
      @data.delete(:points_accepted)
    end

    # delete any series that is flat-line 0/nil
    max = {'hours' => nil, 'points' => nil}
    @data.keys.each{|series|
      units = series.to_s.gsub(/_.*/, '')
      next unless ['points', 'hours'].include?(units)

      max[units] = ([max[units]] + @data[series]).compact.max

      next if series == :points_committed

      @data.delete(series) if @data[series].collect{|d| d.to_f }.uniq == [0.0]
    }

    @data[:max_points] = max['points']
    @data[:max_hours] = max['hours']

    # delete :points:committed if flatline
    @data.delete(:points_committed) if @data[:points_committed].uniq.compact.size < 1
  end

  def [](i)
    i = i.intern if i.is_a?(String)
    return @data[i]
  end

  def series
    return @data.keys.collect{|k| k.to_s}.select{|k| k =~ /^(points|hours)_/}.sort
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

    def self.open_sprints(project_id)
      return Project.find(project_id).shared_versions.open.scoped(:order => 'sprint_start_date ASC, effective_date ASC').collect{|v| v.becomes(RbSprint) }
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

    def days(cutoff = nil)
        # assumes mon-fri are working days, sat-sun are not. this
        # assumption is not globally right, we need to make this configurable.
        cutoff = self.effective_date if cutoff.nil?
        return (self.sprint_start_date .. cutoff).select {|d| (d.wday > 0 and d.wday < 6) }
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
