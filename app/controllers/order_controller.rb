class OrderController < ApplicationController
  protect_from_forgery with: :null_session

  def create
    order_hash = params.require(:order).to_unsafe_h.with_indifferent_access

    items = order_hash[:items] || []

    info_attrs = extract_order_info_attributes(order_hash)
    address_attrs = extract_order_address_attributes(order_hash)

    order_attrs = {
      user_id: order_hash[:user_id],
      name: order_hash[:name] || info_attrs[:first_name],
      surname: order_hash[:surname] || info_attrs[:last_name],
      phone: order_hash[:phone] || info_attrs[:phone],
      address: order_hash[:address]
    }

    if order_attrs[:address].blank? && address_attrs.present?
      parts = []
      parts << address_attrs[:street] if address_attrs[:street].present?
      parts << address_attrs[:city] if address_attrs[:city].present?
      parts << address_attrs[:postal_code] if address_attrs[:postal_code].present?
      parts << address_attrs[:country] if address_attrs[:country].present?
      order_attrs[:address] = parts.join(', ')
      order_attrs[:city] = address_attrs[:city]
      order_attrs[:postal_code] = address_attrs[:postal_code]
      order_attrs[:country] = address_attrs[:country]
    else
      order_attrs[:city] ||= order_hash[:city]
      order_attrs[:postal_code] ||= order_hash[:postal_code]
      order_attrs[:country] ||= order_hash[:country]
    end

    ActiveRecord::Base.transaction do
      @order = Order.create!(order_attrs.merge(total: 0.0, status: 'pending'))
      total = 0.0

      items.each do |it|
        pid = it[:product_id] || (it[:product] && (it[:product][:id] || it[:product]['id']))
        quantity = (it[:quantity] || it['quantity']).to_i
        product = Product.find(pid)
        product.decrement_stock!(quantity)
        price = product.price.to_f
        @order.order_items.create!(product: product, quantity: quantity, price: price)
        total += price * quantity
      end

      @order.update!(total: total)
    end

    render json: { order_id: @order.id }, status: :created
  rescue ActionController::ParameterMissing => e
    render json: { error: e.message }, status: :bad_request
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def extract_order_info_attributes(order_hash)
    if order_hash[:info].present?
      i = order_hash[:info]
      # support both `info` and `info.data`
      data = i[:data] || i
      {
        first_name: data[:firstName] || data[:first_name],
        last_name: data[:lastName] || data[:last_name],
        phone: data[:phone]
      }.compact
    else
      {
        first_name: order_hash[:first_name] || order_hash[:name],
        last_name: order_hash[:last_name] || order_hash[:surname],
        phone: order_hash[:phone]
      }.compact
    end
  end

  def extract_order_address_attributes(order_hash)
    # check order_hash[:info][:data][:address] or order_hash[:info][:address]
    if order_hash[:info].present?
      i = order_hash[:info]
      data = i[:data] || i
      if data[:address].present?
        a = data[:address]
        return {
          street: a[:street] || a['street'],
          city: a[:city] || a['city'],
          postal_code: a[:postalCode] || a[:postal_code] || a['postalCode'] || a['postal_code'],
          country: a[:country] || a['country']
        }.compact
      end
    end

    if order_hash[:address].present?
      return {
        street: order_hash[:address],
        city: order_hash[:city],
        postal_code: order_hash[:postal_code],
        country: order_hash[:country]
      }.compact
    end

    {}
  end
end
