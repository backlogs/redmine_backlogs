include RbCommonHelper

class RbMasterBacklogsController < RbApplicationController
  unloadable

  def show
    product_backlog_stories = RbStory.product_backlog(@project)
    sprints = RbSprint.open_sprints(@project)
    
    last_story = RbStory.find(
                          :first, 
                          :conditions => ["project_id=? AND tracker_id in (?)", @project, RbStory.trackers],
                          :order => "updated_on DESC"
                          )
    @last_update = (last_story ? last_story.updated_on : nil)
    @product_backlog = { :sprint => nil, :stories => product_backlog_stories }
    @sprint_backlogs = sprints.map{ |s| { :sprint => s, :stories => s.stories } }

    respond_to do |format|
      format.html { render :layout => "rb"}
    end
  end

  def menu
    links = []

    links << {:label => 'New Story', :url => '#', :classname => 'add_new_story'}
    links << {:label => 'New Sprint', :url => '#', :classname => 'add_new_sprint'} unless @sprint
    links << {:label => l(:label_task_board), :url => url_for(:controller => 'rb_taskboards', :action => 'show', :sprint_id => @sprint, :only_path => true)} if @sprint && @sprint.stories.size > 0
    links << {:label => 'Burndown chart', :url => '#', :classname => 'show_burndown_chart'} if @sprint && @sprint.stories.size > 0 && @sprint.has_burndown
    links << {:label => l(:label_stories_tasks), :url => url_for(:controller => 'rb_queries', :action => 'show', :project_id => @project, :sprint_id => @sprint, :only_path => true) } if @sprint && @sprint.stories.size > 0
    links << {:label => l(:label_stories), :url => url_for(:controller => 'rb_queries', :action => 'show', :project_id => @project, :only_path => true) } unless @sprint
    links << {:label => l(:label_sprint_cards), :url => url_for(:controller => 'rb_stories', :action => 'index', :project_id => @project.identifier, :sprint_id => @sprint, :format => :pdf, :only_path => true) } if @sprint && BacklogsCards::LabelStock.selected_label && @sprint.stories.size > 0
    links << {:label => l(:label_product_cards), :url => url_for(:controller => 'rb_stories', :action => 'index', :project_id => @project.identifier, :format => :pdf, :only_path => true) } unless @sprint
    links << {:label => l(:label_wiki), :url => url_for(:controller => 'rb_wikis', :action => 'edit', :project_id => @project.id, :sprint_id => @sprint, :only_path => true) } if @sprint && @project.enabled_modules.any? {|m| m.name=="wiki" }
    links << {:label => 'Download', :url => url_for(:controller => 'rb_sprints', :action => 'download', :sprint_id => @sprint, :format => 'xml', :only_path => true) } if @sprint && @sprint.has_burndown

    respond_to do |format|
      format.json { render :json => links }
    end
  end
end
