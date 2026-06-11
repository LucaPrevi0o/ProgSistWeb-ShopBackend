class CartItemSerializer
  def self.call(cart_item)
    {
      product: ProductSerializer.call(cart_item.product),
      quantity: cart_item.quantity
    }
  end
end
