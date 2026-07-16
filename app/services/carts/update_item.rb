module Carts
  class UpdateItem < ApplicationService
    def initialize(user:, product_id:, params:)
      @user = user
      @product_id = product_id
      @params = params.with_indifferent_access
    end

    def call
      quantity = params.fetch(:quantity).to_i
      raise ArgumentError, "Invalid quantity" if quantity < 0

      cart = user.cart || raise(ActiveRecord::RecordNotFound, "Cart not found")
      product = Product.find(product_id)
      cart_item = cart.cart_items.find_by!(product_id: product.id)

      if quantity.zero?
        cart_item.destroy!
      else
        raise ArgumentError, "Insufficient stock" unless product.available?(quantity)

        cart_item.update!(quantity: quantity)
      end

      cart.reload
    end

    private

    attr_reader :user, :product_id, :params
  end
end
