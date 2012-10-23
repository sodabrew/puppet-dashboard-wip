PuppetDashboard::Application.routes do

  root :to => 'pages#home'
  
  resources :node_classes do
    collection do
      get :search
      resources :nodes, :constraints => {:id => /.*/}
    end
  end

  resources :node_groups do
    member do
      get :diff
    end
    collection do
      get :search
      resources :nodes, :constraints => {:id => /.*/}
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

  resources :reports do
    collection do
      get :search
    end
  end

  match 'files/:action/:file1/:file2' => 'files#:action'
  match 'files/:action/:file'         => 'files#:action'

  resources :node_group_memberships, :as => :memberships

  match 'reports/upload' => 'reports#upload', :via => :post
  match '/header.:format' => 'pages#header'

  match 'radiator' => 'radiator#index', :via => :get
  match 'release_notes' => 'pages#release_notes', :via => :get

  match ':controller/:action/:id'
  match ':controller/:action/:id.:format'
end
