class ProductController < ApplicationController
  
  skip_before_action :authenticate_request!, only: [:index, :show]

  def index
    page = params[:page].to_i
    page = 1 if page < 1
    per_page = 8

    # Build filtered relation and then paginate so filtering applies to full dataset
    filtered = Product.apply_filters(params)

    products = filtered.limit(per_page).offset((page - 1) * per_page)

    render json: products
  end

  def show
    product = Product.find(params[:id])
    render json: product
  end
end
