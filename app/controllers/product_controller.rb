class ProductController < ApplicationController
  skip_before_action :authenticate_request!, only: [:index, :show, :categories]

  def index
    page = normalized_query_params[:page].to_i
    page = 1 if page < 1
    per_page = 8

    filtered = Product.apply_filters(normalized_query_params)
    products = filtered.limit(per_page).offset((page - 1) * per_page)
    total_pages = (filtered.count.to_f / per_page).ceil

    response.headers['X-Total-Pages'] = total_pages.to_s
    response.headers['Access-Control-Expose-Headers'] = 'X-Total-Pages'

    render json: products.map { |product| ProductSerializer.call(product) }
  end

  def show
    render json: ProductSerializer.call(Product.find(params[:id]))
  end

  def categories
    render json: Product.where('stock > 0').distinct.order(:category).pluck(:category)
  end
end
