PuppetDashboard::Application.routes do

  root :to => 'pages#home'
  
  resources :node_classes do
    collection do
      get :search
    end
  end

  resources :node_groups do
    member do
      get :diff
    end
    collection do
      get :search
    end
  end

  resources :nodes do
    member do
      put :hide
      put :unhide
      get :facts
      get :reports
    end
    collection do
      get :unreported   , :constraints => {:id => /[^\/]+/}
      get :failed       , :constraints => {:id => /[^\/]+/}
      get :pending      , :constraints => {:id => /[^\/]+/}
      get :unresponsive , :constraints => {:id => /[^\/]+/}
      get :changed      , :constraints => {:id => /[^\/]+/}
      get :unchanged    , :constraints => {:id => /[^\/]+/}
      get :hidden       , :constraints => {:id => /[^\/]+/}
      get :search       , :constraints => {:id => /[^\/]+/}
    end
  end
  
  ## NOTE: the current routes fail when nodes have complete FQDN 
  # e.g., /nodes/host.domain.local would trigger a => No route matches [GET] "/nodes/host.domain.local"
  # Ideally we need to use route globbing
  match 'nodes/(*id)' => 'nodes#show', :via => [:get], :format => false
  match 'nodes/(*id)' => 'nodes#update', :via => [:post], :format => false
  # ...

  resources :reports do
    collection do
      get :search
    end
  end

  resources :node_group_memberships, :as => :memberships

  match 'files/:action/:file1/:file2' => 'files#:action'
  match 'files/:action/:file'         => 'files#:action'

  match '/header.:format' => 'pages#header'
  match 'reports/upload'  => 'reports#upload', :via => :post
  match 'release_notes'   => 'pages#release_notes', :via => :get

  get ':controller(/:action(/:id(.:format)))'

end
