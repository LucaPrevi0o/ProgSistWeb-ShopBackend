class PaymentMethod < ApplicationRecord
  belongs_to :user_info

  # `type` column is used to distinguish payment method kinds (creditCard, payPal, ...)
  # disable ActiveRecord STI handling on `type` so we can store arbitrary values
  self.inheritance_column = :_type_disabled

  validates :type, presence: true
  validates :details, presence: true
end
