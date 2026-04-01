Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  resource :registration, only: %i[new create]

  resource :settings, only: [:show] do
    member do
      get :profile
      get :account
      get :notifications
      get :appearance
      patch :update_profile
      patch :update_account
      patch :update_password
      patch :update_notifications
      patch :update_appearance
    end
  end

  resources :servers do
    member do
      get :settings
      get 'settings/general', to: 'servers#settings_general', as: :settings_general
      get 'settings/invite', to: 'servers#settings_invite', as: :settings_invite
      get 'settings/danger', to: 'servers#settings_danger', as: :settings_danger
    end
    resource :membership, only: [:destroy]
    resources :categories, only: %i[create update destroy]
    resources :channels, only: %i[show create update destroy] do
      resources :messages, only: %i[index show create edit update destroy] do
        resource :thread, only: [:show], controller: 'threads'
      end
    end
  end
  post 'servers/join', to: 'memberships#create', as: :join_server

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get 'up' => 'rails/health#show', as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  root 'servers#index'
end
