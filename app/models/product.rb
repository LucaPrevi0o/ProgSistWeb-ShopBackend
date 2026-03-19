class Product < ApplicationRecord
	# Allowed categories
	CATEGORIES = %w[ELECTRONICS ACCESSORIES CLOTHES BOOKS TOYS HOME BEAUTY UNCATEGORIZED]

	# Validations
	validates :category, presence: true, inclusion: { in: CATEGORIES }
	validates :stock, presence: true,
						numericality: { only_integer: true, greater_than_or_equal_to: 0 }

	# Scopes
	scope :in_stock, -> { where('stock > 0') }

	# filter by category (exact match)
	scope :by_category, ->(category) { where(category: category) if category.present? }

	# filter by name (case-insensitive partial match)
	scope :name_like, ->(name) { where('LOWER(name) LIKE ?', "%#{name.to_s.downcase}%") if name.present? }

	# filter by price range (expects numeric values or parsable strings)
	scope :price_between, ->(min_price, max_price) {
		min = min_price.to_f if min_price.present?
		max = max_price.to_f if max_price.present?
		if min_price.present? && max_price.present?
			where('price >= ? AND price <= ?', min, max)
		elsif min_price.present?
			where('price >= ?', min)
		elsif max_price.present?
			where('price <= ?', max)
		end
	}

	# Compose filters from a params-like hash
	def self.apply_filters(params)
		rel = all
		rel = rel.by_category(params[:category]) if params[:category].present?
		rel = rel.name_like(params[:name]) if params[:name].present?
		rel = rel.price_between(params[:min_price], params[:max_price]) if params[:min_price].present? || params[:max_price].present?
		rel
	end

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
  
	has_many :cart_items, dependent: :destroy
end
