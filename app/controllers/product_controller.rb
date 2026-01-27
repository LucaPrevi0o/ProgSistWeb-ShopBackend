class ProductController < ApplicationController
  def index
    products = Product.all
    render json: products
  end
end
