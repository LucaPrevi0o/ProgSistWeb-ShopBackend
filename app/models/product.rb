class Product < ApplicationRecord
	# Validations
	validates :stock, presence: true,
										numericality: { only_integer: true, greater_than_or_equal_to: 0 }

	# Scopes
	scope :in_stock, -> { where('stock > 0') }

	# Returns true if at least one item is available
	def in_stock?
		stock.to_i > 0
	end

	# Returns true if requested quantity is available
	def available?(quantity = 1)
		stock.to_i >= quantity.to_i
	end

	# Decrements stock by quantity and saves the record.
	# Raises ActiveRecord::RecordInvalid if validation fails.
	def decrement_stock!(quantity = 1)
		q = quantity.to_i
		raise ArgumentError, 'quantity must be positive' if q <= 0

		with_lock do
			raise StandardError, 'insufficient stock' unless available?(q)
			self.stock = stock.to_i - q
			save!
		end
	end
  
	has_many :carts, dependent: :destroy
end
