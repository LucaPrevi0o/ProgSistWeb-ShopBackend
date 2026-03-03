class CartItem < ApplicationRecord
  belongs_to :cart
  belongs_to :product

  validates :quantity, presence: true,
                       numericality: { only_integer: true, greater_than: 0 }

  def subtotal
    (product.price.to_f * quantity).round(2)
  end
end
