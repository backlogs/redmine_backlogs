require 'set'

class YojitsuController < ApplicationController
  unloadable
  before_filter :setup

  def graph_code
    title = Title.new("time entries history.")

    time_entries_line = Line.new
    time_entries_line.default_dot_style = Dot.new
    time_entries_line.text = l(:yjt_time_entry)
    time_entries_line.width = 4
    time_entries_line.dot_size = 5
    time_entries_line.colour = '#DFC329'

    rfp_hours_line = Line.new
    rfp_hours_line.default_dot_style = Dot.new
    rfp_hours_line.text = l(:yjt_rfp_hours)
    rfp_hours_line.width = 4
    rfp_hours_line.dot_size = 5
    rfp_hours_line.colour = '#cc3333'
    
    estimated_hours_line = Line.new
    estimated_hours_line.default_dot_style = Dot.new
    estimated_hours_line.text = l(:yjt_estimated_hours)
    estimated_hours_line.width = 4
    estimated_hours_line.dot_size = 5
    estimated_hours_line.colour = '#336600'

    start_date = @project.time_entries.minimum('spent_on').to_date
    end_date   = @project.time_entries.maximum('spent_on').to_date

    # 開始週～終了週までをつくる
    @weeks = []
    start_week, end_week = start_date.cweek, end_date.cweek
    if start_week <= end_week
        start_week.upto(end_week) { |week| @weeks << week }
    else
        start_week.upto(53) { |week| @weeks << week }
        1.upto(end_week)    { |week| @weeks << week }
    end

    # 週ごとに時間を計算する
    total_time_spent = 0.0
    total_estimated_hours = Set.new
    time_entries = []
    rfp_hours = []
    estimated_hours = []
    labels = []
    @weeks.each do |week|
        ts = @project.time_entries.select { |t| t.spent_on.cweek == week }
        total_time_spent += ts.inject(0.0) {|sum, t| sum + t.hours}
        ts.each do |time_entry|
          next unless time_entry.issue
          next unless time_entry.issue.leaf?
          next unless time_entry.issue.estimated_hours
          total_estimated_hours << time_entry.issue
        end
        time_entries << total_time_spent
        estimated_hours << total_estimated_hours.inject(0.0) {|sum, i| sum + i.estimated_hours}
        rfp_hours << @total_rfp_hours # 見積もり時間は固定

        if ts.empty?
          labels << "-"
        else
          labels << ts.max_by(&:spent_on).spent_on.strftime("%m / %d")
        end
    end
    time_entries_line.values = time_entries
    rfp_hours_line.values = rfp_hours
    estimated_hours_line.values = estimated_hours

    x_labels = XAxisLabels.new(:rotate => 60)
    x_labels.labels = labels
    x = XAxis.new
    x.set_labels(x_labels)

    y = YAxis.new
    y_max = [total_time_spent, @total_rfp_hours].max + 20
    y_step = case y_max
           when 0..100
               y_step = 10
           when 100..500
               y_step = 50
           when 500..1500
               y_step = 100
           else
               y_step = 200
           end
    y.set_range(0, y_max, y_step)

    x_legend = XLegend.new("days")
    x_legend.set_style('{font-size: 20px; color: #778877}')

    y_legend = YLegend.new("hours")
    y_legend.set_style('{font-size: 20px; color: #770077}')

    chart = OpenFlashChart.new
    chart.set_title(title)
    chart.set_x_legend(x_legend)
    chart.set_y_legend(y_legend)
    chart.y_axis = y
    chart.x_axis = x
    chart.add_element(rfp_hours_line)
    chart.add_element(estimated_hours_line)
    chart.add_element(time_entries_line)
    render :text => chart.to_s
  end

  def show
    @graph = open_flash_chart_object(900, 600, "/yojitsu/graph_code/#{params[:id]}")
    
    @category_time_entries = {}
    @category_estimated_hours = {}
    @tracker_time_entries = {}
    @tracker_estimated_hours = {}
    @sprints.each do |sprint|
      sprint.stories.each do |story|
        story.children.each do |task|
          category = task.category || IssueCategory.new(:name => "カテゴリなし")
          @category_time_entries[category.name] ||= 0
          @category_time_entries[category.name] += task.spent_hours
          @category_estimated_hours[category.name] ||= 0
          @category_estimated_hours[category.name] += task.estimated_hours if task.estimated_hours
        end
        tracker = story.tracker
        @tracker_time_entries[tracker.name] ||= 0
        @tracker_time_entries[tracker.name] += story.spent_hours
        @tracker_estimated_hours[tracker.name] ||= 0
        @tracker_estimated_hours[tracker.name] += story.estimated_hours if story.estimated_hours
      end
    end
    @backlog.each do |task|
      category = task.category || IssueCategory.new(:name => "カテゴリなし")
      @category_estimated_hours[category.name] ||= 0
      @category_estimated_hours[category.name] += task.estimated_hours if task.estimated_hours
      @category_time_entries[category.name] ||= 0
      @category_time_entries[category.name] += task.spent_hours if task.spent_hours
    end
  end

  private
  def setup
    @project = Project.find(params[:id])

    # Sprints
    # ※BacklogsプラグインのSprintは将来的にVersionと同一視されなくなるので注意
    @sprints = RbSprint.find(:all, 
                           :order => 'sprint_start_date ASC, effective_date ASC',
                           :conditions => ["project_id = ?", @project.id])

    # rfp hours
    @total_rfp_hours = @project.custom_values[0] ? @project.custom_values[0].to_s.to_f : 0.0

    # estimated hours
    @total_estimated_hours = @sprints.inject(0.0) do |sum, sprint|
      next sum unless sprint.estimated_hours
      sum + sprint.estimated_hours
    end

    # spent hours
    @total_spent_hours = @sprints.inject(0.0) do |sum, sprint|
      next sum unless sprint.spent_hours
      sum + sprint.spent_hours
    end

    # add backlog hours to estimated and spent hours
    @backlog = RbStory.product_backlog(@project)
    @backlog.each do |task|
      @total_estimated_hours += task.estimated_hours if task.estimated_hours
      @total_spent_hours += task.spent_hours if task.spent_hours
    end
    
    @issue_trackers = @project.trackers.all.delete_if {|t| t.id == RbTask.tracker or RbStory.trackers.include?(t.id) }
    @issues = RbStory.find(
                     :all, 
                     :conditions => ["project_id=? AND tracker_id in (?)", @project, @issue_trackers],
                     :order => "position ASC"
                    )
  end
end
