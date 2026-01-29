class CartsController < ApplicationController
  # All actions require authentication via ApplicationController

  # GET /carts
  # Returns current user's cart items
  def index
    carts = @current_user.carts.includes(:product)
    render json: carts.as_json(include: { product: { only: [:id, :name, :price, :stock] } }, methods: :subtotal)
  end

  # POST /carts
  # Params: product_id, quantity (optional)
  def create
    product = Product.find_by(id: cart_params[:product_id])
    return render json: { error: 'Product not found' }, status: :not_found unless product

    qty = (cart_params[:quantity] || 1).to_i
    return render json: { error: 'Invalid quantity' }, status: :unprocessable_entity if qty <= 0

    @cart = @current_user.carts.find_or_initialize_by(product: product)
    new_qty = @cart.new_record? ? qty : (@cart.quantity.to_i + qty)

    unless product.available?(new_qty)
      return render json: { error: 'Insufficient stock' }, status: :unprocessable_entity
    end

    @cart.quantity = new_qty
    if @cart.save
      render json: @cart.as_json(include: { product: { only: [:id, :name, :price, :stock] } }, methods: :subtotal), status: :created
    else
      render json: { error: @cart.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /carts/:id
  # Params: quantity
  def update
    cart = @current_user.carts.find_by(id: params[:id])
    return render json: { error: 'Cart item not found' }, status: :not_found unless cart

    qty = (cart_params[:quantity] || 0).to_i
    return render json: { error: 'Invalid quantity' }, status: :unprocessable_entity if qty <= 0

    unless cart.product.available?(qty)
      return render json: { error: 'Insufficient stock' }, status: :unprocessable_entity
    end

    cart.quantity = qty
    if cart.save
      render json: cart.as_json(include: { product: { only: [:id, :name, :price, :stock] } }, methods: :subtotal)
    else
      render json: { error: cart.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /carts/:id
  def destroy
    cart = @current_user.carts.find_by(id: params[:id])
    return render json: { error: 'Cart item not found' }, status: :not_found unless cart

    cart.destroy
    head :no_content
  end

  # DELETE /carts/clear
  # Removes all cart items for current user
  def clear
    @current_user.carts.destroy_all
    head :no_content
  end

  private

  def cart_params
    params.require(:cart).permit(:product_id, :quantity)
  end
end
