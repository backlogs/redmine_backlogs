include RbCommonHelper

class RbMasterBacklogsController < RbApplicationController
  unloadable

  def show
    product_backlog_stories = RbStory.product_backlog(@project)
    @product_backlog = { :sprint => nil, :stories => product_backlog_stories }

    #collect all sprints which are sharing into @project
    sprints = @project.open_shared_sprints
    @sprint_backlogs = RbStory.backlogs_by_sprint(@project, sprints)

    releases = @project.open_releases_by_date
    @release_backlogs = RbStory.backlogs_by_release(@project, releases)

    @last_update = [product_backlog_stories,
      @sprint_backlogs.map{|s| s[:stories]},
      @release_backlogs.map{|r| r[:releases]}
      ].flatten.compact.map{|s| s.updated_on}.sort.last

    respond_to do |format|
      format.html { render :layout => "rb"}
    end
  end

  def _menu_new
    links = []
    label_new = :label_new_story
    add_class = 'add_new_story'

    if @settings[:sharing_enabled]
      # FIXME: (pa sharing) usability is bad, menu is inconsistent. Sometimes we have a submenu with one entry, sometimes we have non-sharing behavior without submenu
      if @sprint #menu for sprint
        return [] unless @sprint.status == 'open' #closed/locked versions are not assignable versions
        projects = @sprint.shared_to_projects(@project)
      elsif @release #menu for release
        projects = @release.shared_to_projects(@project)
      else #menu for product backlog
        projects = @project.projects_in_shared_product_backlog
      end
      #make the submenu or single link
      if !projects.empty?
        if projects.length > 1
          links << {:label => l(label_new), :url => '#', :sub => []}
          projects.each{|project|
            links.first[:sub] << {:label => project.name, :url => '#', :classname => "#{add_class} project_id_#{project.id}"}
          }
        else
          links << {:label => l(label_new), :url => '#', :classname => "#{add_class} project_id_#{projects[0].id}"}
        end
      end
    else #no sharing, only own project in the menu
      links << {:label => l(label_new), :url => '#', :classname => add_class}
    end
    return links
  end

  def menu
    links = []

    links += _menu_new if User.current.allowed_to?(:create_stories, @project)

    links << {:label => l(:label_new_sprint), :url => '#', :classname => 'add_new_sprint'
             } unless @sprint || !User.current.allowed_to?(:create_sprints, @project)
    links << {:label => l(:label_task_board),
              :url => url_for(:controller => 'rb_taskboards', :action => 'show', :sprint_id => @sprint, :only_path => true)
             } if @sprint && @sprint.stories.size > 0 && Backlogs.task_workflow(@project) && User.current.allowed_to?(:view_taskboards, @project)
    links << {:label =>  l(:label_burndown),
              :url => '#',
              :classname => 'show_burndown_chart'
             } if @sprint && @sprint.stories.size > 0 && @sprint.has_burndown?
    links << {:label => l(:label_stories_tasks),
              :url => url_for(:controller => 'rb_queries', :action => 'show', :project_id => @project.id, :sprint_id => @sprint, :only_path => true)
             } if @sprint && @sprint.stories.size > 0
    links << {:label => l(:label_stories),
              :url => url_for(:controller => 'rb_queries', :action => 'show', :project_id => @project, :only_path => true)
             } unless @sprint || @release
    links << {:label => l(:label_sprint_cards),
              :url => url_for(:controller => 'rb_stories', :action => 'index', :project_id => @project.identifier, :sprint_id => @sprint, :format => 'pdf', :only_path => true)
             } if @sprint && BacklogsPrintableCards::CardPageLayout.selected && @sprint.stories.size > 0
    links << {:label => l(:label_product_cards),
              :url => url_for(:controller => 'rb_stories', :action => 'index', :project_id => @project.identifier, :format => 'pdf', :only_path => true)
             } unless @sprint || @release
    links << {:label => l(:label_wiki),
              :url => url_for(:controller => 'rb_wikis', :action => 'show', :sprint_id => @sprint, :only_path => true)
             } if @sprint && @project.enabled_modules.any? {|m| m.name=="wiki" }
    links << {:label =>  l(:label_download_sprint),
              :url => url_for(:controller => 'rb_sprints', :action => 'download', :sprint_id => @sprint, :format => 'xml', :only_path => true)
             } if @sprint && @sprint.has_burndown?
    links << {:label => l(:label_reset),
              :url => url_for(:controller => 'rb_sprints', :action => 'reset', :sprint_id => @sprint, :only_path => true),
              :warning => view_context().escape_javascript(l(:warning_reset_sprint)).gsub(/\/n/, "\n")
             } if @sprint && @sprint.sprint_start_date && User.current.allowed_to?(:reset_sprint, @project)
    links << {:label => l(:label_version),
              :url => url_for(:controller => 'versions', :action => 'show', :id => @sprint, :target => '_blank', :only_path => true)
             } if @sprint
    links << {:label => l(:label_release),
              :url => url_for(:controller => 'rb_releases', :action => 'show', :release_id => @release, :target => '_blank', :only_path => true)
             } if @release


    respond_to do |format|
      format.html { render :json => links }
    end
  end

  if Rails::VERSION::MAJOR < 3
    def view_context
      @template
    end
  end

  def closed_sprints
    c_sprints = @project.closed_shared_sprints
    @backlogs = RbStory.backlogs_by_sprint(@project, c_sprints)
    respond_to do |format|
      format.html { render :partial => 'closedbacklog', :collection => @backlogs }
    end
  end

end
