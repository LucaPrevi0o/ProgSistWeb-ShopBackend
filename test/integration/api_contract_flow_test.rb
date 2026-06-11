require "test_helper"

class ApiContractFlowTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @product = products(:one)
    @token = Auth::Token.issue(@user)
  end

  test "updates profile with userInfo and methodType" do
    patch "/users/#{@user.id}/user-info",
          params: {
            userInfo: {
              data: {
                firstName: "Mario",
                lastName: "Rossi",
                phone: "3331234567",
                address: {
                  street: "Via Roma 1",
                  city: "Ferrara",
                  postalCode: "44121",
                  country: "Italy"
                }
              },
              paymentMethods: [
                {
                  methodType: "creditCard",
                  details: {
                    cardNumber: "4111111111111111",
                    cardHolderName: "Mario Rossi"
                  }
                }
              ]
            }
          },
          headers: auth_headers

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "Mario", body.dig("userInfo", "data", "firstName")
    assert_equal "44121", body.dig("userInfo", "data", "address", "postalCode")
    assert_equal "creditCard", body.dig("userInfo", "paymentMethods", 0, "methodType")
    assert_equal "Mario Rossi", body.dig("userInfo", "paymentMethods", 0, "details", "cardHolderName")
    assert_nil body["passwordDigest"]
  end

  test "cart lifecycle uses target cart item endpoints" do
    post "/cart/items",
         params: { cartItem: { productId: @product.id, quantity: 2 } },
         headers: auth_headers

    assert_response :success
    assert_equal 2, JSON.parse(response.body).dig("items", 0, "quantity")

    patch "/cart/items/#{@product.id}",
          params: { cartItem: { quantity: 3 } },
          headers: auth_headers

    assert_response :success
    assert_equal 3, JSON.parse(response.body).dig("items", 0, "quantity")

    delete "/cart/items/#{@product.id}", headers: auth_headers

    assert_response :success
    assert_empty JSON.parse(response.body)["items"]
  end

  test "checkout derives user and returns orderId" do
    post "/orders",
         params: {
           order: {
             userId: 999_999,
             items: [
               { product: { id: @product.id }, quantity: 1 }
             ],
             personalData: {
               firstName: "Mario",
               lastName: "Rossi",
               phone: "3331234567",
               address: {
                 street: "Via Roma 1",
                 city: "Ferrara",
                 postalCode: "44121",
                 country: "Italy"
               }
             },
             paymentMethod: {
               methodType: "payPal",
               details: { email: "user@example.com" }
             }
           }
         },
         headers: auth_headers

    assert_response :created
    body = JSON.parse(response.body)
    assert body["orderId"]

    order = Order.find(body["orderId"])
    assert_equal @user.id, order.user_id
    assert_equal "Mario", order.personal_data["firstName"]
    assert_equal "payPal", order.payment_method["methodType"]
  end

  test "auth endpoints expose login me and logout" do
    post "/auth/login", params: { email: @user.email, password: "secret123" }

    assert_response :success
    token = JSON.parse(response.body)["token"]
    assert token.present?

    get "/auth/me", headers: { "Authorization" => "Bearer #{token}" }

    assert_response :success
    assert_equal @user.email, JSON.parse(response.body)["email"]

    post "/auth/logout", headers: { "Authorization" => "Bearer #{token}" }

    assert_response :no_content
  end

  test "orders can be filtered by status and date range" do
    old_order = create_order!(
      status: "pending",
      created_at: 3.days.ago,
      updated_at: 3.days.ago
    )
    create_order!(
      status: "cancelled",
      created_at: 1.day.ago,
      updated_at: 1.day.ago
    )

    get "/orders",
        params: {
          status: "pending",
          fromDate: 4.days.ago.to_date.iso8601,
          toDate: 2.days.ago.to_date.iso8601
        },
        headers: auth_headers

    assert_response :success
    orders = JSON.parse(response.body)
    assert_equal [old_order.id], orders.map { |order| order["id"] }
  end

  private

  def auth_headers
    { "Authorization" => "Bearer #{@token}" }
  end

  def create_order!(attrs = {})
    Order.create!(
      {
        user: @user,
        name: "Mario",
        surname: "Rossi",
        address: "Via Roma 1",
        city: "Ferrara",
        country: "Italy",
        postal_code: "44121",
        total: 10,
        status: "pending",
        personal_data: {
          "firstName" => "Mario",
          "lastName" => "Rossi",
          "address" => { "street" => "Via Roma 1" }
        },
        payment_method: {
          "methodType" => "payPal",
          "details" => { "email" => "user@example.com" }
        }
      }.merge(attrs)
    )
  end
end
