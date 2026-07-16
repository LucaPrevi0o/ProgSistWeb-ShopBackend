module Carts
  class RemoveItem < ApplicationService
    def initialize(user:, product_id:)
      @user = user
      @product_id = product_id
    end

    def call
      cart = user.cart || raise(ActiveRecord::RecordNotFound, "Cart not found")
      cart.cart_items.find_by!(product_id: product_id).destroy!
      cart.reload
    end

    private

    attr_reader :user, :product_id
  end
end
