class User < ApplicationRecord
  has_secure_password

  has_one :user_info, dependent: :destroy
  has_one :cart, dependent: :destroy
  has_many :payment_methods, through: :user_info
end
