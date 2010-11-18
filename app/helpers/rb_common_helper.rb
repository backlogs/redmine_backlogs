module RbCommonHelper
  unloadable
  
  def assignee_id_or_empty(story)
    story.new_record? ? "" : story.assigned_to_id
  end

  def assignee_name_or_empty(story)
    story.blank? || story.assigned_to.blank? ? "" : "#{story.assigned_to.firstname} #{story.assigned_to.lastname}"
  end

  def blocked_ids(blocked)
    blocked.map{|b| b.id }.join(',')
  end

  def build_inline_style(task)
    task.blank? || task.assigned_to.blank? ? '' : "style='background-color:#{task.assigned_to.backlogs_preference(:task_color)}'"
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

  def theme_name
    'rb_default'
  end

  def theme_stylesheet_link_tag(*args)
    themed_args = args.select{ |a| a.class!=Hash }.map{ |s| "#{theme_name}/#{s.to_s}"}
    options = args.select{ |a| a.class==Hash}.first || { }
    options[:plugin] = 'redmine_backlogs'
    themed_args << options
    stylesheet_link_tag *themed_args
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
end
