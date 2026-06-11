require "test_helper"

class ProductControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get "/products"
    assert_response :success
  end

  test "paginates products using page query param" do
    10.times do |index|
      Product.create!(
        name: "Paginated product #{index}",
        description: "Product used to verify pagination",
        category: "Elettronica",
        price: 10 + index,
        stock: 3
      )
    end

    get "/products", params: { page: 1 }
    assert_response :success
    first_page_ids = JSON.parse(response.body).map { |product| product["id"] }

    get "/products", params: { page: 2 }
    assert_response :success
    second_page_ids = JSON.parse(response.body).map { |product| product["id"] }

    assert_not_empty first_page_ids
    assert_not_empty second_page_ids
    assert_not_equal first_page_ids, second_page_ids
  end
end
