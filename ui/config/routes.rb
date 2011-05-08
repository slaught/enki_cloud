ActionController::Routing::Routes.draw do |map|
  map.resources :networks


  map.logout '/logout', :controller => 'sessions', :action => 'destroy'
  map.login '/login', :controller => 'sessions', :action => 'new'
  map.register '/register', :controller => 'users', :action => 'create'
  # map.signup '/signup', :controller => 'users', :action => 'new'
  map.resources :users
  map.resource :session
  # map.resource :bootstrap
  map.connect 'bootstraps/ready/:id', :controller => 'bootstraps', :action => 'ready'
  map.resources :bootstraps
  map.resources :database_configs, :database_names,  :database_clusters
  #map.resource :node, :controller => 'node'
  #map.resource :cluster
  #map.resource :service

  # The priority is based upon order of creation: first created -> highest priority.
  
  # Sample of regular route:
  # map.connect 'products/:id', :controller => 'catalog', :action => 'view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  # map.purchase 'products/:id/purchase', :controller => 'catalog', :action => 'purchase'
  # This route can be invoked with purchase_url(:id => product.id)

  # You can have the root of your site routed by hooking up '' 
  # -- just remember to delete public/index.html.
  map.connect '', :controller => "welcome"

  map.connect 'node/host/*id', :controller => "node", :action => "host"

  # Allow downloading Web Service WSDL as a file with an extension
  # instead of a file named 'wsdl'
  map.connect ':controller/service.wsdl', :action => 'wsdl'

  # tex support
  map.connect ':controller/:action.:format' #, :controller => 'cluster', :action => 'list'

  # Install the default route as the lowest priority.
  map.connect ':controller/:action/:id.:format'
  map.connect ':controller/:action/:id'
end
