require "test_helper"

class OrderTest < ActiveSupport::TestCase
  test "allows a pending order to complete but rejects terminal transitions" do
    order = create_order
    order.update!(status: "completed")

    order.status = "cancelled"

    assert_not order.save
    assert_includes order.errors[:status], "cannot transition from completed to cancelled"
  end

  private

  def create_order
    Order.create!(
      user: users(:one), name: "Mario", surname: "Rossi", address: "Via Roma 1",
      city: "Ferrara", country: "Italy", postal_code: "44121", total: 0, status: "pending"
    )
  end
end
