require "test_helper"

class ApiKeyTransformTest < ActiveSupport::TestCase
  test "underscores api keys and preserves payment details" do
    payload = {
      "paymentMethod" => {
        "methodType" => "creditCard",
        "details" => {
          "cardNumber" => "4111111111111111",
          "cardHolderName" => "Mario Rossi"
        }
      }
    }

    normalized = ApiKeyTransform.underscore_keys(payload)

    assert_equal "creditCard", normalized["payment_method"]["method_type"]
    assert_equal "4111111111111111", normalized["payment_method"]["details"]["cardNumber"]
    assert_equal "Mario Rossi", normalized["payment_method"]["details"]["cardHolderName"]
    assert_nil normalized["payment_method"]["details"]["card_holder_name"]
  end

  test "camelizes rails keys and preserves details" do
    payload = {
      payment_method: {
        method_type: "payPal",
        details: {
          "cardHolderName" => "Mario Rossi"
        }
      }
    }

    serialized = ApiKeyTransform.camelize_keys(payload)

    assert_equal "payPal", serialized[:paymentMethod][:methodType]
    assert_equal "Mario Rossi", serialized[:paymentMethod][:details]["cardHolderName"]
    assert_nil serialized[:paymentMethod][:details]["cardholderName"]
  end
end
