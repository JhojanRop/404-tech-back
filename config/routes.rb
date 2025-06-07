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
  
  resources :user_profiles, except: [:new, :edit] do
    collection do
      get 'by_user/:user_id', to: 'user_profiles#show_by_user'
      put 'by_user/:user_id', to: 'user_profiles#update_by_user'
    end
  end
  
  resources :product_profiles, except: [:new, :edit]
  
  resources :recommendations, only: [:create] do
    collection do
      post :feedback
      get 'user/:user_id', to: 'recommendations#show_by_user'
    end
  end
  
  resources :orders

  post '/login', to: 'users#login'
  post '/register', to: 'users#create'
end
