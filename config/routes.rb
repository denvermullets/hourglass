Rails.application.routes.draw do
  mount MissionControl::Jobs::Engine, at: '/jobs'

  resource :session
  resources :passwords, param: :token
  resource :registration, only: %i[new create]

  namespace :onboarding do
    resource :credentials, only: %i[new create]
    resource :profile, only: %i[show update]
    resource :channels, only: %i[show update]
  end

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

  namespace :settings do
    resources :api_tokens, only: %i[index create destroy]
  end

  namespace :webhooks do
    post 'mtasks/:integration_id', to: 'mtasks#create', as: :mtasks
  end

  namespace :api do
    namespace :v1 do
      get '/me', to: 'users#me'
      resources :servers, only: %i[index show] do
        resources :channels, only: %i[index]
      end
      resources :channels, only: %i[show] do
        resources :messages, only: %i[index create]
      end
      get  '/messages/:id/replies', to: 'messages#replies', as: :message_replies
      post '/messages/:id/replies', to: 'messages#create_reply'
    end
  end

  get '/changelog', to: 'changelog#show', as: :changelog

  get '/mentions/search', to: 'mentions#search', as: :mentions_search

  # Change-check endpoint for the polling-based refresh (Phase 2).
  get '/poll', to: 'poll#show'

  resources :notifications, only: [:index] do
    member do
      patch :mark_read
    end
    collection do
      patch :mark_all_read
    end
  end

  resources :conversations, only: %i[index show create new] do
    member do
      get :mark_read
    end
    resources :messages, only: %i[index show create edit update destroy],
                         controller: 'conversation_messages' do
      resource :thread, only: [:show], controller: 'conversation_threads'
    end
  end
  get 'conversations/users/search', to: 'conversations#user_search', as: :conversation_user_search

  resources :servers do
    member do
      get :members
      get :settings
      get 'settings/general', to: 'servers#settings_general', as: :settings_general
      get 'settings/invite', to: 'servers#settings_invite', as: :settings_invite
      get 'settings/danger', to: 'servers#settings_danger', as: :settings_danger
      get 'settings/channels', to: 'servers#settings_channels', as: :settings_channels
      get 'settings/permissions', to: 'servers#settings_permissions', as: :settings_permissions
      patch 'settings/permissions', to: 'servers#update_permissions', as: :update_permissions
      get 'settings/integrations', to: 'servers#settings_integrations', as: :settings_integrations
      patch 'settings/integrations/jait', to: 'servers#update_jait_integration', as: :update_jait_integration
      post 'settings/integrations/jait/test_webhook', to: 'jait_webhook_tests#create', as: :test_jait_webhook
    end
    resource :membership, only: [:destroy]
    resources :categories, only: %i[create update destroy] do
      member do
        patch :reorder
        patch :archive
        patch :unarchive
      end
    end
    resources :channels, only: %i[show create update destroy] do
      collection do
        get :search
      end
      member do
        get :mark_read
        patch :reorder
        patch :archive
        patch :unarchive
        patch :move
      end
      resources :messages, only: %i[index show create edit update destroy] do
        resource :thread, only: [:show], controller: 'threads'
        member do
          post   :pin
          delete :pin, action: :unpin
        end
      end
      resource :pinned_messages, only: [:show], controller: 'pinned_messages'
      resource :settings, only: %i[show update], controller: 'channels/settings' do
        get :mtasks_projects
        post :link_project
        delete :link_project, action: :unlink_project
      end
    end
  end
  post 'servers/join', to: 'memberships#create', as: :join_server

  get '/jait_cards/:server_id/teams/:team_id/by_identifier/:identifier', to: 'jait_cards#show_by_identifier', as: :jait_card_by_identifier, constraints: { identifier: %r{[^/]+} }
  get '/jait_cards/:server_id/teams/:team_id/:kind(/:id)', to: 'jait_cards#show', as: :jait_card

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get 'up' => 'rails/health#show', as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  root 'servers#index'
end
