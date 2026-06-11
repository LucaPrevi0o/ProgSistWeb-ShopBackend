class PersonalData < ApplicationRecord
  belongs_to :user_info
  has_one :address, dependent: :destroy
end
