require "test_helper"

class ProductTest < ActiveSupport::TestCase
  test "does not decrement stock below zero" do
    product = products(:one)

    error = assert_raises(StandardError) { product.decrement_stock!(product.stock + 1) }

    assert_equal "insufficient stock", error.message
    assert_equal 10, product.reload.stock
  end

  test "requires positive stock changes" do
    product = products(:one)

    assert_raises(ArgumentError) { product.decrement_stock!(0) }
    assert_raises(ArgumentError) { product.increment_stock!(-1) }
  end
end
