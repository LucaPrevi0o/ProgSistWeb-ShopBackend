module Admin
  class OrdersController < ApplicationController
    before_action :require_admin!
    before_action :set_order, only: [:show]

    def index
      orders = Order.includes(:user, order_items: :product).order(created_at: :desc)
      render json: orders.map { |order| OrderSerializer.call(order, include_user: true) }
    end

    def show
      render json: OrderSerializer.call(@order, include_user: true)
    end

    private

    def set_order
      @order = Order.includes(:user, order_items: :product).find_by(id: params[:id])
      return render json: { error: 'Order not found' }, status: :not_found unless @order
    end
  end
end
