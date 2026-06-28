Rails.application.routes.draw do
  devise_for :users

  root "welcome#index"
  get "dashboard", to: "dashboard#show"
  get "current-schedule", to: "schedules#current", as: :current_schedule

  resource :account, only: [ :new, :create, :edit, :update ]

  resources :locations, except: [ :show, :destroy ] do
    patch :deactivate, on: :member

    resources :positions, except: [ :show ] do
      patch :deactivate, on: :member
      patch :reorder, on: :collection
    end

    resources :employees, except: [ :show, :destroy ] do
      patch :deactivate, on: :member
    end

    resources :schedules do
      get :print, on: :member

      resources :shifts, except: [ :index, :show ] do
        patch :move, on: :member
        post :copy, on: :member
      end
    end
  end

  get "positions", to: "positions#index", as: :positions
  get "employees", to: "employees#index", as: :employees
  get "schedules", to: "schedules#index", as: :schedules

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
