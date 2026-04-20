class UserInfo < ApplicationRecord

  belongs_to :user
  has_one :user_address, dependent: :destroy
  has_many :payment_methods, dependent: :destroy
end
