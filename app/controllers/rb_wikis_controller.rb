class RbWikisController < RbApplicationController
  unloadable

  # NOTE: This method is public (see init.rb). We will let Redmine core's
  # WikiController#index tak care of autorization
  # NOTE: this redirection causes a page to be created from a template
  # as a side-effect of calling @sprint.wiki_page. See rb_sprint model.
  def show
    #FIXME not authorizing may be a bad idea. We are creating a public page here... ?
    #@sprint.wiki_page does actually return wiki_page_title. Redmine titleizes this, so do we, even if it is redundant.
    redirect_to :controller => 'wiki', :action => 'show', :project_id => @sprint.project, :id => Wiki.titleize(@sprint.wiki_page)
  end

  # NOTE: This method is public (see init.rb). We will let Redmine core's
  # WikiController#index tak care of autorization
  # NOTE: this redirection causes a page to be created from a template
  # as a side-effect of calling @sprint.wiki_page
  def edit
    redirect_to :controller => 'wiki', :action => 'edit', :project_id => @sprint.project, :id => Wiki.titleize(@sprint.wiki_page)
  end
end
