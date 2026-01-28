class User < ApplicationRecord
  has_secure_password

  has_one :user_info, dependent: :destroy
end
