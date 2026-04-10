class ProductController < ApplicationController
  
  skip_before_action :authenticate_request!, only: [:index, :show]

  def index
    page = params[:page].to_i
    page = 1 if page < 1
    per_page = 8

    # Build filtered relation and then paginate so filtering applies to full dataset
    filtered = Product.apply_filters(params)

    products = filtered.limit(per_page).offset((page - 1) * per_page)

    # expose total pages via response header so frontend can render pagination
    total = filtered.count
    total_pages = (total.to_f / per_page).ceil
    response.headers['X-Total-Pages'] = total_pages.to_s

    render json: products
  end

  def show
    product = Product.find(params[:id])
    render json: product
  end

  def categories
    # return only categories that have at least one product available (stock > 0)
    cats = Product.where('stock > 0').distinct.order(:category).pluck(:category)
    render json: cats
  end
end
