include RbCommonHelper

class RbMasterBacklogsController < RbApplicationController
  unloadable

  def show
    product_backlog_stories = RbStory.product_backlog(@project)
    sprints = RbSprint.open_sprints(@project)

    #TIB (ajout des sprints fermés)
    if @settings[:disable_closed_sprints_to_master_backlogs]
      c_sprints = []
    else
      c_sprints = RbSprint.closed_sprints(@project)
    end

    last_story = RbStory.find(
                          :first,
                          :conditions => ["project_id=? AND tracker_id in (?)", @project.id, RbStory.trackers],
                          :order => "updated_on DESC"
                          )
    @last_update = (last_story ? last_story.updated_on : nil)
    @product_backlog = { :sprint => nil, :stories => product_backlog_stories }
    sprints_backlog_storie_of = RbStory.backlogs_by_sprint(@project, [sprints, c_sprints].flatten)
    @sprint_backlogs = sprints.map{ |s| { :sprint => s, :stories => sprints_backlog_storie_of[s.id] } }
    @c_sprint_backlogs = c_sprints.map{|s| { :sprint => s, :stories => sprints_backlog_storie_of[s.id] } }

    respond_to do |format|
      format.html { render :layout => "rb"}
    end
  end

  def menu
    links = []

    links << {:label => l(:label_new_story), :url => '#', :classname => 'add_new_story'}
    links << {:label => l(:label_new_sprint), :url => '#', :classname => 'add_new_sprint'
             } unless @sprint
    links << {:label => l(:label_task_board),
              :url => url_for(:controller => 'rb_taskboards', :action => 'show', :sprint_id => @sprint, :only_path => true)
             } if @sprint && @sprint.stories.size > 0 && Backlogs.task_workflow(@project)
    links << {:label =>  l(:label_burndown),
              :url => '#',
              :classname => 'show_burndown_chart'
             } if @sprint && @sprint.stories.size > 0 && @sprint.has_burndown?
    links << {:label => l(:label_stories_tasks),
              :url => url_for(:controller => 'rb_queries', :action => 'show', :project_id => @project.id, :sprint_id => @sprint, :only_path => true)
             } if @sprint && @sprint.stories.size > 0
    links << {:label => l(:label_stories),
              :url => url_for(:controller => 'rb_queries', :action => 'show', :project_id => @project, :only_path => true)
             } unless @sprint
    links << {:label => l(:label_sprint_cards),
              :url => url_for(:controller => 'rb_stories', :action => 'index', :project_id => @project.identifier, :sprint_id => @sprint, :format => 'pdf', :only_path => true)
             } if @sprint && BacklogsPrintableCards::CardPageLayout.selected && @sprint.stories.size > 0
    links << {:label => l(:label_product_cards),
              :url => url_for(:controller => 'rb_stories', :action => 'index', :project_id => @project.identifier, :format => 'pdf', :only_path => true)
             } unless @sprint
    links << {:label => l(:label_wiki),
              :url => url_for(:controller => 'rb_wikis', :action => 'edit', :project_id => @project.id, :sprint_id => @sprint, :only_path => true)
             } if @sprint && @project.enabled_modules.any? {|m| m.name=="wiki" }
    links << {:label =>  l(:label_download_sprint),
              :url => url_for(:controller => 'rb_sprints', :action => 'download', :sprint_id => @sprint, :format => 'xml', :only_path => true)
             } if @sprint && @sprint.has_burndown?
    links << {:label => l(:label_reset),
              :url => url_for(:controller => 'rb_sprints', :action => 'reset', :sprint_id => @sprint, :only_path => true),
              :warning => view_context().escape_javascript(l(:warning_reset_sprint)).gsub(/\/n/, "\n")
             } if @sprint && @sprint.sprint_start_date && User.current.allowed_to?(:reset_sprint, @project)


    respond_to do |format|
      format.json { render :json => links }
    end
  end

  if Rails::VERSION::MAJOR < 3
    def view_context
      @template
    end
  end
end
