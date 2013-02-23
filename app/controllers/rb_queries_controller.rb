class RbQueriesController < RbApplicationController
  unloadable

  def show
    @query = __IssueQueryClass.new(:name => "_")
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

    column_names = @query.columns.collect{|col| col.name}
    column_names = column_names + ['position'] unless column_names.include?('position')

    session[:query] = {:project_id => @query.project_id, :filters => @query.filters, :column_names => column_names}
    redirect_to :controller => 'issues', :action => 'index', :project_id => @project.id, :sort => 'position'
  end

  def impediments
    @query = __IssueQueryClass.new(:name => "_")
    @query.project = @project
    @query.add_filter("status_id", 'o', ['']) # only open
    @query.add_filter("fixed_version_id", '=', [params[:sprint_id]])
    @query.add_filter("backlogs_issue_type", '=', ['impediment'])
    session[:query] = {:project_id => @query.project_id, :filters => @query.filters }
    redirect_to :controller => 'issues', :action => 'index', :project_id => @project.id
  end

  private

  def __IssueQueryClass
    if (Redmine::VERSION::MAJOR > 2) || (Redmine::VERSION::MAJOR == 2 && Redmine::VERSION::MINOR >= 3) || Redmine::VERSION::BRANCH == 'devel' #FIXME: remove 'devel' expression when rm 2.3.0 is tagged
      IssueQuery
    else
      Query
    end
  end

end
