require 'date'

class RbSprint < Version
  unloadable

  validate :start_and_end_dates

  def start_and_end_dates
    errors.add(:base, "sprint_end_before_start") if self.effective_date && self.sprint_start_date && self.sprint_start_date >= self.effective_date
  end

  scope :open_sprints, lambda { |project| open_or_locked.by_date.in_project(project) }
  scope :closed_sprints, lambda { |project| closed.by_date.in_project(project) }

  scope :closed, -> { where(:status => 'closed') }
  scope :open_or_locked, -> { where(:status => ['open', 'locked']) }

  def self.by_date_clause
    dir = Backlogs.setting[:sprint_sort_order] == 'desc' ? 'DESC' : 'ASC'
    "CASE #{table_name}.sprint_start_date WHEN NULL THEN 1 ELSE 0 END #{dir},
     #{table_name}.sprint_start_date #{dir},
     CASE #{table_name}.effective_date WHEN NULL THEN 1 ELSE 0 END #{dir},
     #{table_name}.effective_date #{dir}"
  end
  scope :by_date, -> { order(by_date_clause) }
  scope :in_project, lambda {|project| where(:project_id => project) }

  #depending on sharing mode
  #return array of projects where this sprint is visible
  def shared_to_projects(scope_project)
    @shared_projects ||=
      begin
        # Project used when fetching tree sharing
        r = self.project.root? ? self.project : self.project.root
        # Project used for other sharings
        p = self.project
        Project.visible.joins('LEFT OUTER JOIN versions ON versions.project_id = projects.id').
          includes(:versions).
          where(["#{Version.table_name}.id = #{id}" +
          " OR (#{Project.table_name}.status <> #{Project::STATUS_ARCHIVED} AND (" +
          " 'system' = ? " +
          " OR (#{Project.table_name}.lft >= #{r.lft} AND #{Project.table_name}.rgt <= #{r.rgt} AND ? = 'tree')" +
          " OR (#{Project.table_name}.lft > #{p.lft} AND #{Project.table_name}.rgt < #{p.rgt} AND ? IN ('hierarchy', 'descendants'))" +
          " OR (#{Project.table_name}.lft < #{p.lft} AND #{Project.table_name}.rgt > #{p.rgt} AND ? = 'hierarchy')" +
          "))",sharing,sharing,sharing,sharing]).order('lft').distinct
      end
    @shared_projects
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

  def activity
    bd = self.burndown

    # assume a sprint is active if it's only 2 days old
    return true if bd[:hours_remaining] && bd[:hours_remaining].compact.size <= 2

    return Issue.exists?(['fixed_version_id = ? and ((updated_on between ? and ?) or (created_on between ? and ?))', self.id, -2.days.from_now, Time.now, -2.days.from_now, Time.now])
  end

  def impediments
    @impediments ||= Issue.where(
            ["id in (
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
