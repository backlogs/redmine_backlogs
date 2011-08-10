ActionController::Routing::Routes.draw do |map|

  # Use rb/ as a URL 'namespace.' We're using a slightly different URL pattern
  # From Redmine so namespacing avoids any further problems down the line
  map.resource :rb, :only => :none do |rb|
    rb.resource   :updated_items,    :only => :show,               :controller => :rb_updated_items,    :as => "updated_items/:project_id"
    rb.resource   :query,            :only => :show,               :controller => :rb_queries,          :as => "queries/:project_id"
    rb.resource   :query,            :only => :impediments,        :controller => :rb_queries,          :as => "queries/:project_id/:sprint_id"
    rb.resource   :wiki,             :only => [:show, :edit],      :controller => :rb_wikis,            :as => "wikis/:sprint_id"
    rb.resource   :statistics,       :only => :show,               :controller => :rb_statistics
    rb.resource   :task,             :except => :index,            :controller => :rb_tasks,            :as => "task/:id"
    rb.resources  :tasks,            :only => :index,              :controller => :rb_tasks,            :as => "tasks/:story_id"
    rb.resource   :taskboard,        :only => :show,               :controller => :rb_taskboards,       :as => "taskboards/:sprint_id"
    rb.resource   :release,          :only => :show,               :controller => :rb_releases,         :as => "release/:release_id"
    rb.resources  :release,          :only => :edit,               :controller => :rb_releases,         :as => "release/:release_id"
    rb.resources  :release,          :only => :destroy,            :controller => :rb_releases,         :as => "release/:release_id"
    rb.resources  :releases,         :only => :index,              :controller => :rb_releases,         :as => "releases/:project_id"
    rb.resources  :releases,         :only => :snapshot,           :controller => :rb_releases,         :as => "releases/:project_id"

    rb.connect    'server_variables/:project_id.:format',          :controller => :rb_server_variables, :action => 'show'
    rb.connect    ':project_id/conditional-jquery.:format',        :controller => :rb_server_variables, :action => 'jquery'

    rb.connect    'master_backlog/:project_id',                    :controller => :rb_master_backlogs,  :action => 'show'
    rb.connect    'master_backlog/:project_id/menu.:format',       :controller => :rb_master_backlogs,  :action => 'menu'

    rb.connect    'impediment/create',                             :controller => :rb_impediments,      :action => 'create'
    rb.connect    'impediment/update/:id',                         :controller => :rb_impediments,      :action => 'update'

    rb.connect    'sprint/create',                                 :controller => :rb_sprints,          :action => 'create'
    rb.connect    'sprint/update/:sprint_id',                      :controller => :rb_sprints,          :action => 'update'
    rb.connect    'sprint/download/:sprint_id.:format',            :controller => :rb_sprints,          :action => 'download'

    rb.connect    'stories/:project_id/:sprint_id.:format',        :controller => :rb_stories,          :action => 'index'
    rb.connect    'stories/:project_id.:format',                   :controller => :rb_stories,          :action => 'index'
    rb.connect    'story/create',                                  :controller => :rb_stories,          :action => 'create'
    rb.connect    'story/update/:id',                              :controller => :rb_stories,          :action => 'update'

    rb.connect    'calendar/:key/:project_id.:format',             :controller => :rb_calendars,        :action => 'show'

    rb.connect    'burndown/:sprint_id',                           :controller => :rb_burndown_charts,  :action => 'show'
    rb.connect    'burndown/print/:sprint_id',                     :controller => :rb_burndown_charts,  :action => 'print'
  end

end
