class UserInfo < ApplicationRecord
  belongs_to :user
  has_one :personal_data, dependent: :destroy
  has_many :payment_methods, dependent: :destroy
end
