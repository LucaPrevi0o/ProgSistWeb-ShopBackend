class Order < ApplicationRecord
  STATUSES = %w[pending completed cancelled].freeze

  belongs_to :user
  has_many :order_items, dependent: :destroy

  validates :name, presence: true
  validates :surname, presence: true
  validates :address, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :total, numericality: { greater_than_or_equal_to: 0 }
end
