class User < ApplicationRecord

  has_one :user_info, dependent: :destroy
end
