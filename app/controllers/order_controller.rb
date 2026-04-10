class OrderController < ApplicationController
  protect_from_forgery with: :null_session

  # POST /checkout
  # expects payload: { order: { user_id, name, surname, address, city, postal_code, country, phone, items: [ { product_id, quantity } ] } }
  def create
    order_params = params.require(:order).permit(:user_id, :name, :surname, :address, :city, :postal_code, :country, :phone, items: [:product_id, :quantity])
    items = order_params.delete(:items) || []

    ActiveRecord::Base.transaction do
      @order = Order.create!(order_params.merge(total: 0.0, status: 'pending'))
      total = 0.0

      items.each do |it|
        product = Product.find(it[:product_id])
        quantity = it[:quantity].to_i
        product.decrement_stock!(quantity)
        price = product.price.to_f
        @order.order_items.create!(product: product, quantity: quantity, price: price)
        total += price * quantity
      end

      @order.update!(total: total)
    end

    render json: { order_id: @order.id }, status: :created
  rescue ActionController::ParameterMissing => e
    render json: { error: e.message }, status: :bad_request
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end
end
