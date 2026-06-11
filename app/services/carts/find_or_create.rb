module Carts
  class FindOrCreate < ApplicationService
    def initialize(user:)
      @user = user
    end

    def call
      user.cart || user.create_cart!
    end

    private

    attr_reader :user
  end
end
