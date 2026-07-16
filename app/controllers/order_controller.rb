class OrderController < ApplicationController
  def index
    orders = filtered_orders.includes(order_items: :product).order(created_at: :desc)
    render json: orders.map { |order| OrderSerializer.call(order) }
  end

  def show
    order = current_user.orders.includes(order_items: :product).find_by(id: params[:id])
    return render json: { error: "Order not found" }, status: :not_found unless order

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

  private

  def filtered_orders
    filters = normalized_query_params.with_indifferent_access
    orders = current_user.orders
    orders = orders.where(status: filters[:status]) if filters[:status].present?
    orders = orders.where(created_at: parsed_date(filters[:from_date])..) if filters[:from_date].present?

    if filters[:to_date].present?
      to_date = parsed_date(filters[:to_date])
      orders = orders.where(created_at: ..to_date.end_of_day)
    end

    orders
  end

  def parsed_date(value)
    Date.iso8601(value.to_s)
  rescue ArgumentError
    raise ArgumentError, "Invalid date filter: #{value}"
  end
end
