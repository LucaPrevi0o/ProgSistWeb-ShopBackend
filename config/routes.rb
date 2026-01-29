Rails.application.routes.draw do

  get "up" => "rails/health#show", as: :rails_health_check

  get "products" => "product#index"
  get "products/:id" => "product#show"
  post "login" => "auth#login"
  
  get "users" => "user#index"
  get "users/:id" => "user#show"
  
  # Cart endpoints: manage user's cart items
  resources :carts, only: [:index, :create, :update, :destroy] do
    collection do
      delete :clear
    end
  end
end
