Rails.application.routes.draw do
  get 'search/index'
  devise_for :admin_users, ActiveAdmin::Devise.config
  ActiveAdmin.routes(self)
  
  # Public routes
  root "home#index"
  get 'biography', to: 'home#biography'
  get 'editors_statement', to: 'home#editors_statement'
  
  resources :novels, only: [:index, :show] do
    resources :editions, only: [:index, :show]
  end
  
  resources :editions, only: [:index, :show] do
    resources :illustrations, only: [:index, :show]
  end
  
  resources :illustrations, only: [:index, :show]
  resources :illustrators, only: [:index, :show]
  resources :blog_posts, only: [:index, :show], path: 'blog'
  
  # Search route
  get 'search', to: 'search#index'
  
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
end
