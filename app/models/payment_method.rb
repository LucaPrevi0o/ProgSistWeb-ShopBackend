class PaymentMethod < ApplicationRecord
  belongs_to :user_info

  validates :type, presence: true
  validates :details, presence: true
end
