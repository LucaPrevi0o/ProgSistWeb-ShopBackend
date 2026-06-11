module Orders
  class Create < ApplicationService
    def initialize(user:, params:)
      @user = user
      @params = params.with_indifferent_access
    end

    def call
      ActiveRecord::Base.transaction do
        order = Order.create!(order_attributes)
        total = create_order_items(order)
        order.update!(total: total)
        Carts::Clear.call(user: user)
        order
      end
    end

    private

    attr_reader :user, :params

    def order_attributes
      personal_data = params.fetch(:personal_data).with_indifferent_access
      address = (personal_data[:address] || {}).with_indifferent_access

      {
        user: user,
        name: personal_data[:first_name],
        surname: personal_data[:last_name],
        phone: personal_data[:phone],
        address: address[:street],
        city: address[:city],
        postal_code: address[:postal_code],
        country: address[:country],
        status: 'pending',
        total: 0,
        personal_data: PersonalDataSerializer.snapshot(personal_data),
        payment_method: PaymentMethodSerializer.snapshot(params[:payment_method] || {}),
        items: params[:items] || []
      }
    end

    def create_order_items(order)
      Array(params[:items]).sum do |item|
        item = item.with_indifferent_access
        product_id = item[:product_id] || item.dig(:product, :id)
        quantity = item[:quantity].to_i
        raise ArgumentError, 'Invalid quantity' if quantity <= 0

        product = Product.find(product_id)
        product.decrement_stock!(quantity)
        price = product.price.to_f
        order.order_items.create!(product: product, quantity: quantity, price: price)
        price * quantity
      end
    end
  end
end
