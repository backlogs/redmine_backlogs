class RbWikisController < RbApplicationController
  unloadable

  # NOTE: This method is public (see init.rb). We will let Redmine core's
  # WikiController#index tak care of autorization
  # NOTE: this redirection causes a page to be created from a template
  # as a side-effect of calling @sprint.wiki_page
  def show
    redirect_to :controller => 'wiki', :action => 'index', :project_id => @project.id, :id => @sprint.wiki_page
  end

  # NOTE: This method is public (see init.rb). We will let Redmine core's
  # WikiController#index tak care of autorization
  # NOTE: this redirection causes a page to be created from a template
  # as a side-effect of calling @sprint.wiki_page
  def edit
    redirect_to :controller => 'wiki', :action => 'edit', :project_id => @project.id, :id => @sprint.wiki_page
  end
end
