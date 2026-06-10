# app/controllers/admin/orders_controller.rb

module Admin
  class OrdersController < ApplicationController
    before_action :require_admin!
    before_action :set_order, only: [:show]

    def index
      orders = Order.includes(:user).order(created_at: :desc)
      render json: orders.map { |order| serialize_order(order) }
    end

    def show
      render json: serialize_order(@order)
    end

    private

    def set_order
      @order = Order.includes(:user).find_by(id: params[:id])
      return render json: { error: 'Order not found' }, status: :not_found unless @order
    end

    def serialize_order(order)
      {
        id: order.id,
        userId: order.user_id,
        user: {
          id: order.user.id,
          email: order.user.email
        },
        personalData: order.personal_data,
        items: order.items,
        paymentMethod: order.payment_method,
        total: order.total,
        createdAt: order.created_at
      }
    end
  end
end