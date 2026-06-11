class OrderController < ApplicationController
  def index
    orders = current_user.orders.includes(order_items: :product).order(created_at: :desc)
    render json: orders.map { |order| OrderSerializer.call(order) }
  end

  def show
    order = current_user.orders.includes(order_items: :product).find_by(id: params[:id])
    return render json: { error: 'Order not found' }, status: :not_found unless order

    render json: OrderSerializer.call(order)
  end

  def create
    order = Orders::Create.call(user: current_user, params: normalized_resource(:order))
    render json: { orderId: order.id }, status: :created
  rescue KeyError => e
    render json: { error: e.message }, status: :bad_request
  rescue ActiveRecord::RecordNotFound => e
    render json: { error: e.message }, status: :not_found
  rescue ActiveRecord::RecordInvalid, ArgumentError, StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end
end
