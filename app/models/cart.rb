class Cart < ApplicationRecord
  belongs_to :user
  belongs_to :product

  validates :quantity, presence: true,
                       numericality: { only_integer: true, greater_than: 0 }

  # Returns subtotal price for this cart line
  def subtotal
    (product.price.to_f * quantity).round(2)
  end
end
