class OrderController < ApplicationController

  def index
    # return orders belonging to current authenticated user
    orders = Order.where(user_id: @current_user.id).order(created_at: :desc)

    payload = orders.map do |o|
      {
        id: o.id,
        userId: o.user_id,
        personalData: o.personal_data || {},
        paymentMethod: o.payment_method || {},
        items: o.order_items.map do |oi|
          {
            product: (oi.product&.as_json || { 'id' => oi.product_id }),
            quantity: oi.quantity,
            price: oi.price.to_f
          }
        end,
        total: o.total.to_f,
        status: o.status,
        createdAt: o.created_at,
        updatedAt: o.updated_at,
        address: o.address,
        city: o.city,
        postalCode: o.postal_code
      }
    end

    render json: payload
  end

  def create
    order_hash = params.require(:order).to_unsafe_h.with_indifferent_access

    items = order_hash[:items] || []

    info_attrs = extract_order_info_attributes(order_hash)
    address_attrs = extract_order_address_attributes(order_hash)

    # Prefer camelCase `personalData` from frontend, fall back to flattened fields
    personal = order_hash[:personalData] || order_hash[:personal_data]

    # Normalize nested structures so both string and symbol keys (and camelCase) work
    if personal.is_a?(Hash)
      personal = personal.with_indifferent_access
    end

    items = (items || []).map do |it|
      if it.is_a?(Hash)
        it = it.with_indifferent_access
        if it[:product].is_a?(Hash)
          it[:product] = it[:product].with_indifferent_access
        end
      end

      it
    end

    order_attrs = {
      user_id: order_hash[:userId] || order_hash[:user_id],
      name: personal&.dig(:firstName) || personal&.dig('firstName') || order_hash[:name] || info_attrs[:first_name],
      surname: personal&.dig(:lastName) || personal&.dig('lastName') || order_hash[:surname] || info_attrs[:last_name],
      phone: personal&.dig(:phone) || personal&.dig('phone') || order_hash[:phone] || info_attrs[:phone],
      address: order_hash[:address]
    }

    # If address is provided under `personal.address`, prefer that
    if order_attrs[:address].blank? && personal.present? && personal[:address].present?
      addr = personal[:address]
      if addr.is_a?(Hash)
        parts = []
        parts << addr[:street] if addr[:street].present?
        parts << addr[:city] if addr[:city].present?
        parts << addr[:postalCode] if addr[:postalCode].present?
        parts << addr[:country] if addr[:country].present?
        order_attrs[:address] = parts.join(', ')
        order_attrs[:city] = addr[:city]
        order_attrs[:postal_code] = addr[:postalCode] || addr[:postal_code]
        order_attrs[:country] = addr[:country]
      else
        order_attrs[:address] = addr
      end
    end

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
      order_attrs[:postal_code] ||= order_hash[:postal_code] || order_hash[:postalCode]
      order_attrs[:country] ||= order_hash[:country]
    end

    ActiveRecord::Base.transaction do
      @order = Order.create!(order_attrs.merge(total: 0.0, status: 'pending'))
      total = 0.0

      items.each do |it|
        pid = it[:product_id] || (it[:product] && (it[:product][:id] || it[:product]['id'])) || it['product_id']
        quantity = (it[:quantity] || it['quantity']).to_i
        product = Product.find(pid)
        product.decrement_stock!(quantity)
        price = product.price.to_f
        @order.order_items.create!(product: product, quantity: quantity, price: price)
        total += price * quantity
      end

      # store original payload pieces so frontend-shaped Order is preserved
      personal_data_json = if personal.present?
                             personal
                           else
                             addr = {
                               'street' => address_attrs[:street] || order_hash[:address],
                               'city' => address_attrs[:city] || order_hash[:city],
                               'postalCode' => address_attrs[:postal_code] || order_hash[:postal_code] || order_hash[:postalCode],
                               'country' => address_attrs[:country] || order_hash[:country]
                             }.compact

                             {
                               'firstName' => info_attrs[:first_name],
                               'lastName' => info_attrs[:last_name],
                               'phone' => info_attrs[:phone],
                               'address' => addr
                             }.compact
                           end

      payment_method_json = order_hash[:paymentMethod] || order_hash[:payment_method] || order_hash[:payment] || {}

      @order.update!(total: total, personal_data: personal_data_json, items: items, payment_method: payment_method_json)
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
