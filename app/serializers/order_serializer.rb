class OrderSerializer
  def self.call(order, include_user: false)
    payload = {
      id: order.id,
      user_id: order.user_id,
      items: order.order_items.includes(:product).map { |order_item| serialize_item(order_item) },
      personal_data: PersonalDataSerializer.snapshot(order.personal_data),
      payment_method: PaymentMethodSerializer.snapshot(order.payment_method),
      total: order.total.to_f,
      status: order.status,
      created_at: order.created_at
    }

    payload[:user] = { id: order.user.id, email: order.user.email } if include_user && order.user

    ApiKeyTransform.camelize_keys(payload)
  end

  def self.serialize_item(order_item)
    {
      product: ProductSerializer.call(order_item.product),
      quantity: order_item.quantity,
      price: order_item.price.to_f
    }
  end
end
