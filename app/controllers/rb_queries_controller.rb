class RbQueriesController < RbApplicationController
  unloadable

  def show
    @query = Query.new(:name => "_")
    @query.project = @project

    if params[:sprint_id]
        @query.add_filter("status_id", '*', ['']) # All statuses
        @query.add_filter("fixed_version_id", '=', [params[:sprint_id]])
        @query.add_filter("backlogs_issue_type", '=', ['any'])
    else
        @query.add_filter("status_id", 'o', ['']) # only open
        @query.add_filter("fixed_version_id", '!*', ['']) # only unassigned
        @query.add_filter("backlogs_issue_type", '=', ['story'])
    end

    #column_names = @query.columns.collect{|col| col.name}
    column_names = Array.new
    column_names = column_names + ['id'] unless column_names.include?('id')
    column_names = column_names + ['position'] unless column_names.include?('position')    
    column_names = column_names + ['tracker'] unless column_names.include?('tracker')
    column_names = column_names + ['subject'] unless column_names.include?('subject')
    column_names = column_names + ['relative_gain'] unless column_names.include?('relative_gain')
    column_names = column_names + ['relative_penalty'] unless column_names.include?('relative_penalty')
    column_names = column_names + ['story_points'] unless column_names.include?('story_points')
    column_names = column_names + ['relative_risk'] unless column_names.include?('relative_risk')
    column_names = column_names + ['relative_priority'] unless column_names.include?('relative_priority')
    
    session[:query] = {:project_id => @query.project_id, :filters => @query.filters, :column_names => column_names}
    redirect_to :controller => 'issues', :action => 'index', :project_id => @project.id, :sort => 'position'
  end

  def impediments
    @query = Query.new(:name => "_")
    @query.project = @project
    @query.add_filter("status_id", 'o', ['']) # only open
    @query.add_filter("fixed_version_id", '=', [params[:sprint_id]])
    @query.add_filter("backlogs_issue_type", '=', ['impediment'])
    session[:query] = {:project_id => @query.project_id, :filters => @query.filters }
    redirect_to :controller => 'issues', :action => 'index', :project_id => @project.id
  end
end
