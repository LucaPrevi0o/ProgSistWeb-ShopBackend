class PaymentMethod < ApplicationRecord
  belongs_to :user_info

  validates :method_type, presence: true
  validates :details, presence: true
end
