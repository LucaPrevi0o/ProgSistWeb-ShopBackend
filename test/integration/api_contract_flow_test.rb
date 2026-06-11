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

  private

  def auth_headers
    { "Authorization" => "Bearer #{@token}" }
  end
end
