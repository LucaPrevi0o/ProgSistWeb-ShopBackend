class Cart < ApplicationRecord
  belongs_to :user

  has_many :cart_items, dependent: :destroy

  # Returns total price for the whole cart
  def total
    cart_items.includes(:product).sum { |ci| ci.subtotal }
  end
end
