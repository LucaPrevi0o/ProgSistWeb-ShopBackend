class ProductController < ApplicationController
  
  skip_before_action :authenticate_request!, only: [:index, :show]

  def index
    products = Product.all
    render json: products
  end

  def show
    product = Product.find(params[:id])
    render json: product
  end
end
