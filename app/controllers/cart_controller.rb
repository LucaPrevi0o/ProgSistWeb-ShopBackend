class CartController < ApplicationController
  def create
    cart = Carts::FindOrCreate.call(user: current_user)
    render json: CartSerializer.call(cart), status: :created
  end

  def show
    cart = current_user.cart || Carts::FindOrCreate.call(user: current_user)
    render json: CartSerializer.call(cart)
  end

  def add_item
    cart = Carts::AddItem.call(user: current_user, params: normalized_resource(:cart_item))
    render json: CartSerializer.call(cart)
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Product not found' }, status: :not_found
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def update_item
    cart = Carts::UpdateItem.call(
      user: current_user,
      product_id: params[:product_id],
      params: normalized_resource(:cart_item)
    )
    render json: CartSerializer.call(cart)
  rescue ActiveRecord::RecordNotFound => e
    render json: { error: e.message }, status: :not_found
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def remove_item
    cart = Carts::RemoveItem.call(user: current_user, product_id: params[:product_id])
    render json: CartSerializer.call(cart)
  rescue ActiveRecord::RecordNotFound => e
    render json: { error: e.message }, status: :not_found
  end

  def destroy
    Carts::Clear.call(user: current_user)
    head :no_content
  end
end
