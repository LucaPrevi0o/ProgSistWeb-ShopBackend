require "test_helper"

class AuthorizationTest < ActionDispatch::IntegrationTest
  test "rejects unauthenticated cart access" do
    get "/cart"

    assert_response :unauthorized
    assert_equal "Bearer realm=\"Application\"", response.headers["WWW-Authenticate"]
  end

  test "rejects a customer from administrator endpoints" do
    get "/admin/orders", headers: auth_headers(users(:one))

    assert_response :forbidden
  end

  test "does not expose an order to another customer" do
    order = Order.create!(
      user: users(:one), name: "Mario", surname: "Rossi", address: "Via Roma 1",
      city: "Ferrara", country: "Italy", postal_code: "44121", total: 0, status: "pending"
    )
    other_user = User.create!(email: "other@example.com", password: "secret123")

    get "/orders/#{order.id}", headers: auth_headers(other_user)

    assert_response :not_found
  end

  private

  def auth_headers(user)
    { "Authorization" => "Bearer #{Auth::Token.issue(user)}" }
  end
end
