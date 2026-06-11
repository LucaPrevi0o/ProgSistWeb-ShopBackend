Rails.application.routes.draw do

  get "up" => "rails/health#show", as: :rails_health_check

  get "products" => "product#index"
  get "products/:id" => "product#show"
  get "categories" => "product#categories"
  
  post "auth/login" => "auth#login"
  post "auth/logout" => "auth#logout"
  get "auth/me" => "auth#me"

  post "users" => "user#create"

  get "admin/me" => "admin#me"
  
  get "users" => "user#index"
  get "users/:id" => "user#show"
  patch "users/:id/user-info" => "user#update_info"
  
  get "cart" => "cart#show"
  post "cart" => "cart#create"
  post "cart/items" => "cart#add_item"
  patch "cart/items/:product_id" => "cart#update_item"
  delete "cart/items/:product_id" => "cart#remove_item"
  delete "cart" => "cart#destroy"
  post "orders" => "order#create"
  get "orders" => "order#index"
  get "orders/:id" => "order#show"

  namespace :admin do
    resources :products, only: [:index, :show, :create, :update, :destroy]
    resources :orders, only: [:index, :show]
    resources :users, only: [:index, :show]
  end
end
