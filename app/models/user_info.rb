class UserInfo < ApplicationRecord
  belongs_to :user
  has_many :payment_methods, dependent: :destroy

  if respond_to?(:attribute)
    attribute :data, :json, default: {}
  else
    serialize :data, JSON
  end

  def data_hash
    (self.data || {}).with_indifferent_access
  end
end
