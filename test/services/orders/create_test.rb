require "test_helper"

class Orders::CreateTest < ActiveSupport::TestCase
  test "rolls back an order and stock when stock is exhausted" do
    product = products(:two)

    assert_raises(StandardError) do
      Orders::Create.call(user: users(:one), params: checkout_params(product, product.stock + 1))
    end

    assert_equal 0, users(:one).orders.count
    assert_equal 5, product.reload.stock
  end

  test "creates order lines, decrements stock, and clears the cart" do
    user = users(:one)
    product = products(:one)
    Carts::AddItem.call(user: user, params: { product_id: product.id, quantity: 2 })

    order = Orders::Create.call(user: user, params: checkout_params(product, 2))

    assert_equal 2, order.order_items.first.quantity
    assert_equal 99.98, order.total.to_f
    assert_equal 8, product.reload.stock
    assert_empty user.cart.reload.cart_items
  end

  private

  def checkout_params(product, quantity)
    {
      items: [{ product_id: product.id, quantity: quantity }],
      personal_data: {
        first_name: "Mario", last_name: "Rossi",
        address: { street: "Via Roma 1", city: "Ferrara", postal_code: "44121", country: "Italy" }
      },
      payment_method: { method_type: "cash" }
    }
  end
end
