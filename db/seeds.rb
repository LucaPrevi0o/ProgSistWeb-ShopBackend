# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here is idempotent so it can be executed at any time.
# Load with `bin/rails db:seed` or during `db:setup`.

products = [
	{ name: 'Classic T-Shirt', description: 'Comfortable 100% cotton t-shirt in multiple sizes and colors.', price: 19.99, stock: 120 },
	{ name: 'Slim Jeans', description: 'Modern slim-fit jeans with stretch for comfort.', price: 49.5, stock: 60 },
	{ name: 'Running Sneakers', description: 'Lightweight sneakers designed for daily running and training.', price: 89.0, stock: 40 },
	{ name: 'Leather Wallet', description: 'Genuine leather bi-fold wallet with coin pocket.', price: 39.0, stock: 80 },
	{ name: 'Wireless Headphones', description: 'Over-ear bluetooth headphones with noise cancellation.', price: 129.99, stock: 25 },
	{ name: 'Ceramic Mug', description: '350ml ceramic mug, dishwasher safe.', price: 9.5, stock: 200 },
	{ name: 'Backpack 20L', description: 'Durable 20-litre backpack for daily use and short trips.', price: 59.0, stock: 50 }
]

Product.transaction do
	products.each do |attrs|
		p = Product.find_or_initialize_by(name: attrs[:name])
		p.description = attrs[:description]
		p.price = attrs[:price]
		p.stock = attrs[:stock]
		p.save!
	end
end

puts "Seeded #{products.size} products (created or updated)."
