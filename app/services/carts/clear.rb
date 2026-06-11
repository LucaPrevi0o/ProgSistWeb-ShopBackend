module Carts
  class Clear < ApplicationService
    def initialize(user:)
      @user = user
    end

    def call
      user.cart&.cart_items&.destroy_all
    end

    private

    attr_reader :user
  end
end
