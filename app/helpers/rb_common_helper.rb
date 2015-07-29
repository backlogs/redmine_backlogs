require 'color'
require 'nokogiri'

module RbCommonHelper
  unloadable

  include CustomFieldsHelper
  include RbPartialsHelper

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

  def breadcrumb_separator
    "<span class='separator'>&raquo;</span>".html_safe
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
    item.new_record? ? "" : link_to(text, {:controller => 'versions', :action => "show", :id => item}, {:target => "_blank", :class => "prevent_edit"})
  end

  def release_display_name(release)
    if @project == release.project
      release.name
    else
      "#{release.project.try(:identifier)}-#{release.name}"
    end
  end

  def release_link_or_empty(release)
    release.new_record? ? "" : link_to(release_display_name(release), {:controller => "rb_releases", :action => "show", :release_id => release})
  end

  def release_multiview_link_or_empty(release)
    release.new_record? ? "" : link_to(release_display_name(release), {:controller => "rb_releases_multiview", :action => "show", :release_multiview_id => release})
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

  def release_or_empty(story)
    story.release_id.nil? ? "" : RbRelease.find(story.release_id).name
  end

  def sprint_status_id_or_default(sprint)
    sprint.new_record? ? Version::VERSION_STATUSES.first : sprint.status
  end

  def sprint_status_label_or_default(sprint)
    sprint.new_record? ? l("version_status_#{Version::VERSION_STATUSES.first}") : l("version_status_#{sprint.status}")
  end

  def status_id_or_default(story)
    #story.new_record? ? IssueStatus.default.id : story.status.id
    if story.new_record?
      story.default_status ? story.default_status.id : 0
    else
      story.status ? story.status.id : 0
    end
  end

  def status_label_or_default(story)
    #story.new_record? ? IssueStatus.default.name : story.status.name
    if story.new_record?
      story.default_status ? story.default_status.name : ""
    else
      story.status ? story.status.name : ""
    end
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

  def tracker_id_or_empty(story)
    story.new_record? ? "" : story.tracker_id
  end

  def tracker_name_or_empty(story)
    story.new_record? ? "" : story.tracker.name
  end

  def project_name_or_empty(story)
    story.new_record? ? "" : story.project.name
  end

  def custom_fields_or_empty(story)
    return '' if story.new_record?
    res = ''
    story.custom_field_values.each{|value|
      res += "<p><b>#{h(value.custom_field.name)}</b>: #{simple_format_without_paragraph(h(show_value(value)))}</p>"
    }
    res.html_safe
  end

  def updated_on_with_milliseconds(story)
    date_string_with_milliseconds(story.updated_on, 0.001) unless story.blank?
  end

  def date_string_with_milliseconds(d, add=0)
    return '' if d.blank?
    d.strftime("%B %d, %Y %H:%M:%S") + '.' + (d.to_f % 1 + add).to_s.split('.')[1] + d.strftime(" %z")
  end

  def remaining_hours_or_empty(item)
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

  def csv_encode(s)
    if RUBY_VERSION >= "1.9"
      s.encode(l(:general_csv_encoding))
    else
      Iconv.conv(l(:general_csv_encoding), 'UTF-8', s)
    end
  rescue
    s
  end

  def release_burndown_to_csv(release)
    # FIXME decimal_separator is not used, instead a hardcoded s/\./,/g is done
    # below to make (German) Excel happy
    #decimal_separator = l(:general_csv_decimal_separator)

    export = FCSV.generate(:col_sep => ';') do |csv|
      # csv header fields
      headers = [ l(:label_points_backlog),
                  l(:label_points_added),
                  l(:label_points_accepted)
                ]
      csv << headers.collect {|c| csv_encode(c.to_s) }

      bd = release.burndown
      lines = 0
      lines = bd[:added_points].size unless bd[:added_points].nil?
      for i in (0..(lines-1))
        fields = [ bd[:added_points][i].to_s.gsub('.', ','),
                   bd[:backlog_points][i].to_s.gsub('.', ','),
                   bd[:closed_points][i].to_s.gsub('.', ',')
                 ]
        csv << fields.collect{ |c| csv_encode(c.to_s) }
      end
    end
    export
  end

  def self.find_backlogs_enabled_active_projects
    #projects =
    EnabledModule.where(name: 'backlogs')
                  .includes(:project)
                  .joins(:project).where(projects: {status: Project::STATUS_ACTIVE})
                  .collect { |mod| mod.project}
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

    if collection.include?(User.current)
      el = User.current
      s << "<option value=\"#{el.id}\" color=\"#{el.backlogs_preference[:task_color]}\" color_light=\"#{el.backlogs_preference[:task_color_light]}\">&lt;&lt; #{l(:label_me)} &gt;&gt;</option>"
    end

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
    s.html_safe
  end

  def release_options_for_select(releases, selected=nil)
    releases = releases.all.to_a if releases
    grouped = Hash.new {|h,k| h[k] = []}
    selected = [selected].compact unless selected.kind_of?(Array)
    releases.each do |release|
      grouped[release.project.name] << [release.name, release.id]
    end
    # Add in the selected
    (selected.to_a - releases.to_a).each{|s| grouped[s.project.name] << [s.name, s.id] }

    if grouped.keys.size > 1
      grouped_options_for_select(grouped, selected.collect{|s| s.id})
    else
      options_for_select((grouped.values.first || []), selected.collect{|s| s.id})
    end
  end

  # Convert selected ids to integer and remove blank values.
  def selected_ids(options)
    return nil if options.nil?
    options.collect{|o| o.to_i unless o.blank?}.compact! 
  end

  def format_release_sharing(v)
    RbRelease::RELEASE_SHARINGS.include?(v) ? l("label_version_sharing_#{v}") : "none"
  end

  #fixup rails base uri which is not obeyed IF url_for is used in a redmine layout hook
  def url_for_prefix_in_hooks
#    if Rails::VERSION::MAJOR < 3
#      '' #actionpack-2.3.14/lib/action_controller/url_rewriter.rb is injecting relative_url_root
#    else
#      Redmine::Utils.relative_url_root #actionpack-3* is not???
#    end
     '' #Rails4 yet another behavior
  end
end
