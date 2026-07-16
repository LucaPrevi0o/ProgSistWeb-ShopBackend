module Admin
  class OrdersController < ApplicationController
    before_action :require_admin!
    before_action :set_order, only: [ :show, :status ]

    def index
      orders = Order.includes(:user, order_items: :product).order(created_at: :desc)
      render json: orders.map { |order| OrderSerializer.call(order, include_user: true) }
    end

    def show
      render json: OrderSerializer.call(@order, include_user: true)
    end

    def status
      @order.update!(status: params.require(:status))
      render json: OrderSerializer.call(@order.reload, include_user: true)
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: "Validation failed", details: e.record.errors.full_messages }, status: :unprocessable_entity
    end

    private

    def set_order
      @order = Order.includes(:user, order_items: :product).find_by(id: params[:id])
      render json: { error: "Order not found" }, status: :not_found unless @order
    end
  end
end
