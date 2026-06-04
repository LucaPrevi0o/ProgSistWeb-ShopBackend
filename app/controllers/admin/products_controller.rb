module Admin
  class ProductsController < ApplicationController
    before_action :require_admin!
    before_action :set_product, only: [:show, :update, :destroy]

    def index
      products = Product.order(:id)
      render json: products
    end

    def show
      render json: @product
    end

    def create
      product = Product.create!(product_params)
      render json: product, status: :created
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: 'Validation failed', details: e.record.errors.full_messages }, status: :unprocessable_entity
    end

    def update
      @product.update!(product_params)
      render json: @product
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: 'Validation failed', details: e.record.errors.full_messages }, status: :unprocessable_entity
    end

    def destroy
      @product.destroy!
      head :no_content
    end

    private

    def set_product
      @product = Product.find_by(id: params[:id])
      render json: { error: 'Product not found' }, status: :not_found unless @product
    end

    def product_params
      params.require(:product).permit(:name, :description, :category, :price, :stock)
    end
  end
end
