if Rails::VERSION::MAJOR < 3
ActionController::Routing::Routes.draw do |map|
  # Use rb/ as a URL 'namespace.' We're using a slightly different URL pattern
  # From Redmine so namespacing avoids any further problems down the line
  map.resource :rb, :only => :none do |rb|
    rb.resource   :updated_items,    :only => :show,                :controller => :rb_updated_items,   :as => "updated_items/:project_id"
    rb.resource   :wiki,             :only => [:show, :edit],       :controller => :rb_wikis,           :as => "wikis/:sprint_id"
    rb.resource   :task,             :except => :index,             :controller => :rb_tasks,           :as => "task/:id"
    rb.resources  :tasks,            :only => :index,               :controller => :rb_tasks,           :as => "tasks/:story_id"
    rb.resource   :taskboard,        :only => :show,                :controller => :rb_taskboards,      :as => "taskboards/:sprint_id"
    rb.resource   :release, :only => [:show, :edit, :destroy, :snapshot], :controller => :rb_releases,  :as => "release/:release_id",   :member => {:snapshot => :get, :edit => :post}
    rb.resources  :release,          :only => :new,                 :controller => :rb_releases,        :as => "release/:project_id",   :new => { :new => :post }
    rb.resources  :releases,         :only => :index,               :controller => :rb_releases,        :as => "releases/:project_id"

    rb.connect    'issues/backlog/product/:project_id',             :controller => :rb_queries,           :action => 'show'
    rb.connect    'issues/backlog/sprint/:sprint_id',               :controller => :rb_queries,           :action => 'show'
    rb.connect    'issues/impediments/sprint/:sprint_id',           :controller => :rb_queries,           :action => 'impediments'

    rb.connect    'statistics',                                     :controller => :rb_all_projects,      :action => 'statistics'

    rb.connect    'server_variables/project/:project_id.js',        :controller => :rb_server_variables,  :action => 'project', :format => 'js'
    rb.connect    'server_variables/project/:project_id',           :controller => :rb_server_variables,  :action => 'project', :format => nil
    rb.connect    'server_variables/sprint/:sprint_id.js',          :controller => :rb_server_variables,  :action => 'sprint', :format => 'js'
    rb.connect    'server_variables/sprint/:sprint_id',             :controller => :rb_server_variables,  :action => 'sprint', :format => nil
    rb.connect    'server_variables.js',                            :controller => :rb_server_variables,  :action => 'index', :format => 'js'
    rb.connect    'server_variables',                               :controller => :rb_server_variables,  :action => 'index', :format => nil

    rb.connect    'master_backlog/:project_id',                     :controller => :rb_master_backlogs,   :action => 'show'
    rb.connect    'master_backlog/:project_id/menu.json',           :controller => :rb_master_backlogs,   :action => 'menu', :format => 'json'

    rb.connect    'impediment/create',                              :controller => :rb_impediments,       :action => 'create'
    rb.connect    'impediment/update/:id',                          :controller => :rb_impediments,       :action => 'update'

    rb.connect    'sprint/create',                                  :controller => :rb_sprints,          :action => 'create'
    rb.connect    'sprint/:sprint_id/update',                       :controller => :rb_sprints,          :action => 'update'
    rb.connect    'sprint/:sprint_id/reset',                        :controller => :rb_sprints,          :action => 'reset'
    rb.connect    'sprint/download/:sprint_id.xml',                 :controller => :rb_sprints,          :action => 'download', :format => 'xml'
    rb.connect    'sprints/:project_id/close_completed',            :controller => :rb_sprints,          :action => 'close_completed'

    rb.connect    'stories/sprint/:sprint_id.pdf',                  :controller => :rb_stories,          :action => 'index', :format => 'pdf'
    rb.connect    'stories/project/:project_id.pdf',                :controller => :rb_stories,          :action => 'index', :format => 'pdf'
    rb.connect    'story/create',                                   :controller => :rb_stories,          :action => 'create'
    rb.connect    'story/update/:id',                               :controller => :rb_stories,          :action => 'update'

    rb.connect    'calendar/:key/:project_id.ics',                  :controller => :rb_calendars,        :action => 'ical', :format => 'xml'

    rb.connect    'burndown/:sprint_id',                            :controller => :rb_burndown_charts,  :action => 'show'
    rb.connect    'burndown/:sprint_id/embed',                      :controller => :rb_burndown_charts,  :action => 'embedded'
    rb.connect    'burndown/:sprint_id/print',                      :controller => :rb_burndown_charts,  :action => 'print'

    rb.connect    'hooks/sidebar/sprint/:sprint_id',                :controller => :rb_hooks_render,     :action => 'view_issues_sidebar'
    rb.connect    'hooks/sidebar/project/:project_id',              :controller => :rb_hooks_render,     :action => 'view_issues_sidebar'
  end

end

else
  resource :rb, :only => :none do |rb|
  match 'updated_items/:project_id', :to => 'rb_updated_items#show'

  match 'queries/:project_id', :to => 'rb_queries#show'
  match  'queries/:project_id/:sprint_id', :to => 'rb_queries#impediments'

  match 'wikis/:sprint_id', :to => 'rb_wikis#show'
  match 'wikis/:sprint_id', :to => 'rb_wikis#edit'

  resources :task, :except => :index, :controller => :rb_tasks
  match 'tasks/:story_id', :to => 'rb_tasks#index'

  match 'taskboards/:sprint_id',
            :to => 'rb_taskboards#show'

  match 'releases/:project_id', :to => 'rb_releases#index'

  match 'staticstics', :to => 'rb_all_projects#statistics'

  match 'server_variables/sprint/:sprint_id.js',
              :to => 'rb_server_variables#sprint',
              :format => 'js'
  match 'server_variables/sprint/:sprint_id.js',
              :to => 'rb_server_variables#sprint',
              :format => nil
  match 'server_variables.js',
              :to => 'rb_server_variables#index',
              :format => 'js'
  match 'server_variables.js',
              :to => 'rb_server_variables#index',
              :format => nil
  match 'server_variables/project/:project_id.js',
              :to => 'rb_server_variables#project',
              :format => 'js'
  match 'server_variables/project/:project_id.js',
              :to => 'rb_server_variables#project',
              :format => nil

  match 'master_backlog/:project_id', :to => 'rb_master_backlogs#show'

  match 'master_backlog/:project_id/menu.json', :to => 'rb_master_backlogs#menu', :format => 'json'

  match 'impediment/create', :to => 'rb_impediments#create'
  match 'impediment/update/:id', :to => 'rb_impediments#update'

  match 'sprint/create', :to => 'rb_sprints#create'
  match 'sprint/:sprint_id/update', :to => 'rb_sprints#update'
  match 'sprint/:sprint_id/reset', :to => 'rb_sprints#reset'
  match 'sprint/download/:sprint_id.xml', :to => 'rb_sprints#download', :format => 'xml'
  match 'sprints/:project_id/close_completed', :to => 'rb_sprints#close_completed'

  match 'stories/:project_id/:sprint_id.pdf', :to => 'rb_stories#index', :format => 'pdf'
  match 'stories/:project_id.pdf', :to => 'rb_stories#index', :format => 'pdf'
  match 'story/create', :to => 'rb_stories#create'
  match 'story/update/:id', :to => 'rb_stories#update'

  match 'calendar/:key/:project_id.ics', :to => 'rb_calendars#ical',
          :format => 'xml'

  match 'burndown/:sprint_id',         :to => 'rb_burndown_charts#show'
  match 'burndown/:sprint_id/embed',   :to => 'rb_burndown_charts#embedded'
  match 'burndown/:sprint_id/print',   :to => 'rb_burndown_charts#print'

  match 'hooks/sidebar/project/:project_id',
          :to => 'rb_hooks_render#view_issues_sidebar'
  match 'hooks/sidebar/project/:project_id/:sprint_id',
          :to => 'rb_hooks_render#view_issues_sidebar'
  end
end

