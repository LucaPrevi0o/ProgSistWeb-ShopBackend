class CartSerializer
  def self.call(cart)
    {
      id: cart.id,
      user: UserSerializer.call(cart.user),
      items: cart.cart_items.includes(:product).map { |cart_item| CartItemSerializer.call(cart_item) },
      total: cart.total
    }
  end
end
