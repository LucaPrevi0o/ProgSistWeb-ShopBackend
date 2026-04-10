class Order < ApplicationRecord
  belongs_to :user, optional: true
  has_many :order_items, dependent: :destroy

  validates :name, presence: true
  validates :surname, presence: true
  validates :address, presence: true
  validates :total, numericality: { greater_than_or_equal_to: 0 }
end
