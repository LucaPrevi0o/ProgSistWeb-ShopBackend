module Carts
  class AddItem < ApplicationService
    def initialize(user:, params:)
      @user = user
      @params = params.with_indifferent_access
    end

    def call
      product = Product.find(params[:product_id])
      quantity = (params[:quantity] || 1).to_i
      raise ArgumentError, 'Invalid quantity' if quantity <= 0

      cart = Carts::FindOrCreate.call(user: user)
      cart_item = cart.cart_items.find_by(product_id: product.id)
      new_quantity = cart_item ? cart_item.quantity + quantity : quantity
      raise ArgumentError, 'Insufficient stock' unless product.available?(new_quantity)

      CartItem.transaction do
        cart_item ||= cart.cart_items.build(product: product)
        cart_item.quantity = new_quantity
        cart_item.save!
      end

      cart.reload
    end

    private

    attr_reader :user, :params
  end
end
