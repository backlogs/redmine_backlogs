def rb_match(object, path, hash)
  if Rails::VERSION::MAJOR < 3
    hash[:controller] = hash[:to].split('#')[0].to_sym
    hash[:action] = hash[:to].split('#')[1]
    hash.delete(:to)
    if hash[:via]
      hash[:conditions] = { :method => hash[:via] }
      hash.delete(:via)
    end
    object.connect path, hash
  else
    match path, hash
  end
end

def rb_common_routes(rb)
  rb_match rb, 'releases/:project_id',
               :to => 'rb_releases#index', :via => [:get]
  rb_match rb, 'release/:project_id/new',
               :to => 'rb_releases#new', :via => [:get, :post]
  rb_match rb, 'release/:release_id',
               :to => 'rb_releases#show', :via => [:get]
  rb_match rb, 'release/:release_id',
               :to => 'rb_releases#destroy', :via => [:delete]
  rb_match rb, 'release/:release_id/edit',
               :to => 'rb_releases#edit', :via => [:get, :post]
  rb_match rb, 'release/:release_id/update',
               :to => 'rb_releases#update', :via => [:put]
  rb_match rb, 'release/:release_id/shapshot',
               :to => 'rb_releases#snapshot', :via => [:get]

  rb_match rb, 'releases_multiview/:project_id/new',
               :to => 'rb_releases_multiview#new', :via => [:get, :post]
  rb_match rb, 'releases_multiview/:release_multiview_id',
               :to => 'rb_releases_multiview#show', :via => [:get]
  rb_match rb, 'releases_multiview/:release_multiview_id',
               :to => 'rb_releases_multiview#destroy', :via => [:delete]
  rb_match rb, 'releases_multiview/:release_multiview_id/edit',
               :to => 'rb_releases_multiview#edit', :via => [:get, :post]

  rb_match rb, 'updated_items/:project_id', :to => 'rb_updated_items#show'
  rb_match rb, 'wikis/:sprint_id', :to => 'rb_wikis#show'
  rb_match rb, 'wikis/:sprint_id/edit', :to => 'rb_wikis#edit'
  rb_match rb, 'issues/backlog/product/:project_id',
               :to => 'rb_queries#show'
  rb_match rb, 'issues/backlog/sprint/:sprint_id',
               :to => 'rb_queries#show'
  rb_match rb, 'issues/impediments/sprint/:sprint_id',
               :to => 'rb_queries#impediments'
  rb_match rb, 'statistics', :to => 'rb_all_projects#statistics'

  rb_match rb, 'server_variables/sprint/:sprint_id.js',
              :to => 'rb_server_variables#sprint',
              :format => 'js'
  rb_match rb, 'server_variables/sprint/:sprint_id.js',
              :to => 'rb_server_variables#sprint',
              :format => nil
  rb_match rb, 'server_variables.js',
              :to => 'rb_server_variables#index',
              :format => 'js'
  rb_match rb, 'server_variables.js',
              :to => 'rb_server_variables#index',
              :format => nil
  rb_match rb, 'server_variables/project/:project_id.js',
              :to => 'rb_server_variables#project',
              :format => 'js'
  rb_match rb, 'server_variables/project/:project_id.js',
              :to => 'rb_server_variables#project',
              :format => nil

  rb_match rb, 'master_backlog/:project_id',
               :to => 'rb_master_backlogs#show'
  rb_match rb, 'master_backlog/:project_id/menu',
               :to => 'rb_master_backlogs#menu'
  rb_match rb, 'master_backlog/:project_id/closed_sprints', :to => 'rb_master_backlogs#closed_sprints'

  rb_match rb, 'impediment/create', :to => 'rb_impediments#create'
  rb_match rb, 'impediment/update/:id', :to => 'rb_impediments#update'

  rb_match rb, 'sprint/create', :to => 'rb_sprints#create'
  rb_match rb, 'sprint/:sprint_id/update', :to => 'rb_sprints#update'
  rb_match rb, 'sprint/:sprint_id/reset', :to => 'rb_sprints#reset'
  rb_match rb, 'sprint/download/:sprint_id.xml', :to => 'rb_sprints#download', :format => 'xml'
  rb_match rb, 'sprints/:project_id/close_completed', :to => 'rb_sprints#close_completed', :via => [:put]

  rb_match rb, 'stories/:project_id/:sprint_id.pdf', :to => 'rb_stories#index', :format => 'pdf'
  rb_match rb, 'stories/:project_id.pdf', :to => 'rb_stories#index', :format => 'pdf'
  rb_match rb, 'story/create', :to => 'rb_stories#create'
  rb_match rb, 'story/update/:id', :to => 'rb_stories#update'
  rb_match rb, 'story/:id/tooltip', :to => 'rb_stories#tooltip'

  rb_match rb, 'calendar/:key/:project_id.ics', :to => 'rb_calendars#ical',
          :format => 'xml'

  rb_match rb, 'burndown/:sprint_id',         :to => 'rb_burndown_charts#show'
  rb_match rb, 'burndown/:sprint_id/embed',   :to => 'rb_burndown_charts#embedded'
  rb_match rb, 'burndown/:sprint_id/print',   :to => 'rb_burndown_charts#print'

  rb_match rb, 'hooks/sidebar/project/:project_id',
          :to => 'rb_hooks_render#view_issues_sidebar'
  rb_match rb, 'hooks/sidebar/project/:project_id/:sprint_id',
          :to => 'rb_hooks_render#view_issues_sidebar'

  rb_match rb, 'project/:project_id/backlogs', :to => 'rb_project_settings#project_settings'
end

if Rails::VERSION::MAJOR < 3
ActionController::Routing::Routes.draw do |map|
  # Use rb/ as a URL 'namespace.' We're using a slightly different URL pattern
  # From Redmine so namespacing avoids any further problems down the line
  map.resource :rb, :only => :none do |rb|
    rb.resource   :task,             :except => :index,             :controller => :rb_tasks,           :as => "task/:id"
    rb.resources  :tasks,            :only => :index,               :controller => :rb_tasks,           :as => "tasks/:story_id"
    rb.resource   :taskboard,        :only => :show,                :controller => :rb_taskboards,      :as => "taskboards/:sprint_id"
    rb.resource   :taskboard,        :only => :current,             :controller => :rb_taskboards,      :as => "projects/:project_id/taskboard"

    rb_common_routes rb
  end
end

else
  resource :rb, :only => :none do |rb|

  # releases
#  resources :projects do
#    resources :releases, :only => [:index, :new,:show, :edit, :destroy, :snapshot], :controller => :rb_releases  do
#      get 'snapshot', :on => :member 
#      post 'edit', :on => :member
#      post 'new', :on => :member
#    end
#  end

    rb_common_routes rb

  resources :task, :except => :index, :controller => :rb_tasks
  rb_match rb, 'tasks/:story_id', :to => 'rb_tasks#index'

  rb_match rb, 'taskboards/:sprint_id',
            :to => 'rb_taskboards#show'
  rb_match rb, 'projects/:project_id/taskboard',
            :to => 'rb_taskboards#current'
  end
end

