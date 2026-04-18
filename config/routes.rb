Rails.application.routes.draw do

  get "up" => "rails/health#show", as: :rails_health_check

  get "products" => "product#index"
  get "products/:id" => "product#show"
  get "categories" => "product#categories"
  
  post "login" => "auth#login"
  post "users" => "user#create"
  
  get "users" => "user#index"
  get "users/:id" => "user#show"
  post "users/:id/info" => "user#create_info"
  patch "users/:id/info" => "user#update_info"
  
  get "cart" => "cart#show"
  post "cart" => "cart#create"
  post "cart/new" => "cart#add_item"
  patch "cart/item" => "cart#update_item"
  delete "cart/item" => "cart#remove_item"
  delete "cart" => "cart#destroy"
  post "checkout" => "order#create"
end
