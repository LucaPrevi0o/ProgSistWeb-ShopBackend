Rails.application.routes.draw do

  get "up" => "rails/health#show", as: :rails_health_check

  get "products" => "product#index"
  
  get "users" => "user#index"
  get "users/:id" => "user#show"
end
