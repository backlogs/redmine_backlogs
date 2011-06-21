include RbCommonHelper

class RbWikiController < RbApplicationController
  unloadable

  def show
    @project = Project.find(params[:project_id])
    @wiki = @project.wiki
    
    @page = @wiki.find_page(@wiki.start_page)
    @content = @page.content
    @editable = editable?

    render :action => 'show', :layout => 'empty'
  end
  
  def editable?(page = @page)
    page.editable_by?(User.current)
  end
end
