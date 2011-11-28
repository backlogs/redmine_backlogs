ActionController::Routing::Routes.draw do |map|

  # Use rb/ as a URL 'namespace.' We're using a slightly different URL pattern
  # From Redmine so namespacing avoids any further problems down the line
  map.resource :rb, :only => :none do |rb|
    rb.resource   :updated_items,    :only => :show,                :controller => :rb_updated_items,   :as => "updated_items/:project_id"
    rb.resource   :query,            :only => :show,                :controller => :rb_queries,         :as => "queries/:project_id"
    rb.resource   :query,            :only => :impediments,         :controller => :rb_queries,         :as => "queries/:project_id/:sprint_id"
    rb.resource   :wiki,             :only => [:show, :edit],       :controller => :rb_wikis,           :as => "wikis/:sprint_id"
    rb.resource   :task,             :except => :index,             :controller => :rb_tasks,           :as => "task/:id"
    rb.resources  :tasks,            :only => :index,               :controller => :rb_tasks,           :as => "tasks/:story_id"
    rb.resource   :taskboard,        :only => :show,                :controller => :rb_taskboards,      :as => "taskboards/:sprint_id"
    rb.resource   :release,          :only => :show,                :controller => :rb_releases,        :as => "release/:release_id"
    rb.resources  :release,          :only => :edit,                :controller => :rb_releases,        :as => "release/:release_id"
    rb.resources  :release,          :only => :destroy,             :controller => :rb_releases,        :as => "release/:release_id"
    rb.resources  :releases,         :only => :index,               :controller => :rb_releases,        :as => "releases/:project_id"
    rb.resources  :releases,         :only => :snapshot,            :controller => :rb_releases,        :as => "releases/:project_id"

    rb.connect    'statistics',                                     :controller => :rb_all_projects,      :action => 'statistics'

    rb.connect    'server_variables/:project_id/:caller.js',        :controller => :rb_server_variables,  :action => 'show', :format => 'js'
    rb.connect    'server_variables/:sprint_id/:caller.js',         :controller => :rb_server_variables,  :action => 'show', :format => 'js'
    rb.connect    'server_variables.js',                            :controller => :rb_all_projects,      :action => 'server_variables', :format => 'js'

    rb.connect    'master_backlog/:project_id',                     :controller => :rb_master_backlogs,   :action => 'show'
    rb.connect    'master_backlog/:project_id/menu.json',           :controller => :rb_master_backlogs,   :action => 'menu', :format => 'json'

    rb.connect    'impediment/create',                              :controller => :rb_impediments,       :action => 'create'
    rb.connect    'impediment/update/:id',                          :controller => :rb_impediments,       :action => 'update'

    rb.connect    'sprint/create',                                  :controller => :rb_sprints,          :action => 'create'
    rb.connect    'sprint/:sprint_id/update',                       :controller => :rb_sprints,          :action => 'update'
    rb.connect    'sprint/:sprint_id/reset',                        :controller => :rb_sprints,          :action => 'reset'
    rb.connect    'sprint/download/:sprint_id.xml',                 :controller => :rb_sprints,          :action => 'download', :format => 'xml'

    rb.connect    'stories/:project_id/:sprint_id.pdf',             :controller => :rb_stories,          :action => 'index', :format => 'pdf'
    rb.connect    'stories/:project_id.pdf',                        :controller => :rb_stories,          :action => 'index', :format => 'pdf'
    rb.connect    'story/create',                                   :controller => :rb_stories,          :action => 'create'
    rb.connect    'story/update/:id',                               :controller => :rb_stories,          :action => 'update'

    rb.connect    'calendar/:key/:project_id.ics',                  :controller => :rb_calendars,        :action => 'ical', :format => 'api'

    rb.connect    'burndown/:sprint_id',                            :controller => :rb_burndown_charts,  :action => 'show'
    rb.connect    'burndown/:sprint_id/embed',                      :controller => :rb_burndown_charts,  :action => 'embedded'
    rb.connect    'burndown/:sprint_id/print',                      :controller => :rb_burndown_charts,  :action => 'print'

    rb.connect    'hooks/sidebar/:project_id/:sprint_id',           :controller => :rb_hooks_render,     :action => 'view_issues_sidebar'
    rb.connect    'hooks/sidebar/:project_id',                      :controller => :rb_hooks_render,     :action => 'view_issues_sidebar'
  end

end
