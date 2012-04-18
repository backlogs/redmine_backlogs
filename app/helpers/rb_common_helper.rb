require 'color'
require 'nokogiri'

module RbCommonHelper
  unloadable
  
  def assignee_id_or_empty(story)
    story.new_record? ? "" : story.assigned_to_id
  end

  def assignee_name_or_empty(story)
    story.blank? || story.assigned_to.blank? ? "" : "#{story.assigned_to.name}"
  end

  def blocked_ids(blocked)
    blocked.map{|b| b.id }.join(',')
  end

  def build_inline_style(task)
    if (task.blank? || task.assigned_to.blank? || !task.assigned_to.is_a?(User))
      ''
    else
      color_to = task.assigned_to.backlogs_preference[:task_color]
      color_from = Backlogs::Color.new(color_to).lighten(0.5)
      "style='
background-color:#{task.assigned_to.backlogs_preference[:task_color]}; 
background: -webkit-gradient(linear, left top, left bottom, from(#{color_from}), to(#{color_to}));
background: -moz-linear-gradient(top, #{color_from}, #{color_to});
filter:progid:DXImageTransform.Microsoft.Gradient(Enabled=1,GradientType=0,StartColorStr=#{color_from},EndColorStr=#{color_to});
'"
    end
  end

  def build_inline_style_color(task)
    task.blank? || task.assigned_to.blank? || !task.assigned_to.is_a?(User) ? '' : "#{task.assigned_to.backlogs_preference[:task_color]}"
  end 
  
  def breadcrumb_separator
    "<span class='separator'>&gt;</span>"
  end

  def description_or_empty(story)
    story.new_record? ? "" : textilizable(story, :description)
  end

  def id_or_empty(item)
    item.new_record? ? "" : item.id
  end

  def issue_link_or_empty(item)
    item_id = item.id.to_s
    text = (item_id.length > 8 ? "#{item_id[0..1]}...#{item_id[-4..-1]}" : item_id)
    item.new_record? ? "" : link_to(text, {:controller => "issues", :action => "show", :id => item}, {:target => "_blank", :class => "prevent_edit"})
  end

  def sprint_link_or_empty(item)
    item_id = item.id.to_s
    text = (item_id.length > 8 ? "#{item_id[0..1]}...#{item_id[-4..-1]}" : item_id)
    item.new_record? ? "" : link_to(text, {:controller => "sprint", :action => "show", :id => item}, {:target => "_blank", :class => "prevent_edit"})
  end

  def release_link_or_empty(release)
    release.new_record? ? "" : link_to(release.name, {:controller => "rb_releases", :action => "show", :release_id => release})
  end

  def mark_if_closed(story)
    !story.new_record? && story.status.is_closed? ? "closed" : ""
  end

  def story_points_or_empty(story)
    story.story_points.blank? ? "" : story.story_points
  end

  def record_id_or_empty(story)
    story.new_record? ? "" : story.id
  end
  
  def sprint_status_id_or_default(sprint)
    sprint.new_record? ? Version::VERSION_STATUSES.first : sprint.status
  end

  def sprint_status_label_or_default(sprint)
    sprint.new_record? ? l("version_status_#{Version::VERSION_STATUSES.first}") : l("version_status_#{sprint.status}")
  end
  
  def status_id_or_default(story)
    story.new_record? ? IssueStatus.find(:first, :order => "position ASC").id : story.status.id
  end

  def status_label_or_default(story)
    story.new_record? ? IssueStatus.find(:first, :order => "position ASC").name : story.status.name
  end

  def sprint_html_id_or_empty(sprint)
    sprint.new_record? ? "" : "sprint_#{sprint.id}"
  end

  def story_html_id_or_empty(story)
    story.new_record? ? "" : "story_#{story.id}"
  end

  def release_html_id_or_empty(release)
    release.new_record? ? "" : "release_#{release.id}"
  end

  def textile_description_or_empty(story)
    story.new_record? ? "" : h(story.description).gsub(/&lt;(\/?pre)&gt;/, '<\1>')
  end
  
  def textile_to_html(textile)
    textile.nil? ? "" : Redmine::WikiFormatting::Textile::Formatter.new(textile).to_html
  end

  def tracker_id_or_empty(story)
    story.new_record? ? "" : story.tracker_id
  end

  def tracker_name_or_empty(story)
    story.new_record? ? "" : story.tracker.name
  end
  
  def updated_on_with_milliseconds(story)
    date_string_with_milliseconds(story.updated_on, 0.001) unless story.blank?
  end

  def date_string_with_milliseconds(d, add=0)
    return '' if d.blank?
    d.strftime("%B %d, %Y %H:%M:%S") + '.' + (d.to_f % 1 + add).to_s.split('.')[1]
  end

  def remaining_hours(item)
    item.remaining_hours.blank? || item.remaining_hours==0 ? "" : item.remaining_hours
  end

  def workdays(start_day, end_day)
    return (start_day .. end_day).select {|d| (d.wday > 0 and d.wday < 6) }
  end

  def release_burndown_interpolate(release, day)
    initial_day = release.burndown.days[0]
    initial_points = release.burndown.remaining_story_points[0]
    day_diff = initial_points / (release.days.size - 1.0)
    initial_points - ( (workdays(initial_day, day).size - 1) * day_diff )
  end

  def release_burndown_to_csv(release)
    ic = Iconv.new(l(:general_csv_encoding), 'UTF-8')

    # FIXME decimal_separator is not used, instead a hardcoded s/\./,/g is done
    # below to make (German) Excel happy
    #decimal_separator = l(:general_csv_decimal_separator)

    export = FCSV.generate(:col_sep => ';') do |csv|
      # csv header fields
      headers = [ l(:label_date),
                  l(:remaining_story_points),
                  l(:ideal)
                ]
      csv << headers.collect {|c| begin; ic.iconv(c.to_s); rescue; c.to_s; end }

      # csv lines
      if (release.release_start_date != release.burndown_days[0])
        fields = [release.release_start_date,
                  release.initial_story_points.to_f.to_s.gsub('.', ','),
                  release.initial_story_points.to_f.to_s.gsub('.', ',')]
        csv << fields.collect {|c| begin; ic.iconv(c.to_s); rescue; c.to_s; end }
      end
      release.burndown_days.each do |rbd|
        fields = [rbd.day,
                  rbd.remaining_story_points.to_s.gsub('.', ','),
                  release_burndown_interpolate(release, rbd.day).to_s.gsub('.', ',')
                 ]
        csv << fields.collect {|c| begin; ic.iconv(c.to_s); rescue; c.to_s; end }
      end
      if (release.release_end_date != release.burndown_days[-1])
        fields = [release.release_end_date, "", "0,0"]
        csv << fields.collect {|c| begin; ic.iconv(c.to_s); rescue; c.to_s; end }
      end
    end
    export
  end

  # Renders the project quick-jump box
  def render_backlog_project_jump_box
    projects = EnabledModule.find(:all,
                             :conditions => ["enabled_modules.name = 'backlogs' and status = ?", Project::STATUS_ACTIVE],
                             :include => :project,
                             :joins => :project).collect { |mod| mod.project}

    projects = Member.find(:all, :conditions => ["user_id = ? and project_id IN (?)", User.current.id, projects.collect(&:id)]).collect{ |m| m.project}

    if projects.any?
      s = '<select onchange="if (this.value != \'\') { window.location = this.value; }">' +
            "<option value=''>#{ l(:label_jump_to_a_project) }</option>" +
            '<option value="" disabled="disabled">---</option>'
      s << project_tree_options_for_select(projects, :selected => @project) do |p|
        { :value => url_for(:controller => 'rb_master_backlogs', :action => 'show', :project_id => p, :jump => current_menu_item) }
      end
      s << '</select>'
      s
    end
  end

  # Returns a collection of users allowed to log time for the current project. (see app/views/rb_taskboards/show.html.erb for usage)
  def users_allowed_to_log_on_task
    @project.memberships.collect{|m|
      user = m.user
      roles = user ? user.roles_for_project(@project) : nil
      roles && roles.detect {|role| role.member? && role.allowed_to?(:log_time)} ? [user.name, user.id] : nil
    }.compact.insert(0,["",0]) # Add blank entry
  end

  def tidy(html)
    return Nokogiri::HTML::fragment(html).to_xhtml
  end

  def users_assignable_options_for_select(collection)
    s = ''
    groups = ''
    collection.sort.each do |element|
      if element.is_a?(Group)
        groups << "<option value=\"#{element.id}\" color=\"#AAAAAA\" color_light=\"#E0E0E0\">#{h element.name}</option>"
      else
        s << "<option value=\"#{element.id}\" color=\"#{element.backlogs_preference[:task_color]}\" color_light=\"#{element.backlogs_preference[:task_color_light]}\">#{h element.name}</option>"
      end
    end
    unless groups.empty?
      s << %(<optgroup label="#{h(l(:label_group_plural))}">#{groups}</optgroup>)
    end
    s
  end

end
