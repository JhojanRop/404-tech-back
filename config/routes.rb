Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  resources :products do
    collection do
      get :categories
    end
  end
  resources :discount_codes, except: [:new, :edit] do
    member do
      post :consume
    end
  end
  
  resources :users, except: [:new, :edit]
  resources :recommendations, only: [:index, :show]
  resources :orders

  post '/login', to: 'users#login'
  post '/register', to: 'users#create'

  post '/ai/recommendations', to: 'ai#recommendations'
end
