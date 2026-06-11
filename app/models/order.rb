class Order < ApplicationRecord
  STATUSES = %w[pending completed cancelled].freeze

  belongs_to :user
  has_many :order_items, dependent: :destroy

  validates :name, presence: true
  validates :surname, presence: true
  validates :address, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :total, numericality: { greater_than_or_equal_to: 0 }

  before_update :restore_stock_after_cancellation, if: :will_save_change_to_status?

  private

  def restore_stock_after_cancellation
    return unless status == 'cancelled'
    return if status_was == 'cancelled'

    order_items.includes(:product).find_each do |order_item|
      order_item.product.increment_stock!(order_item.quantity)
    end
  end
end
