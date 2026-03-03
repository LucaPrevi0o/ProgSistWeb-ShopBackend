class CartController < ApplicationController
  # All actions require authentication via ApplicationController
  # POST /cart
  # Creates a Cart for current user (if not present)
  def create
    if @current_user.cart
      render json: serialize_cart(@current_user.cart)
    else
      cart = Cart.new(user: @current_user)
      if cart.save
        render json: serialize_cart(cart), status: :created
      else
        render json: { error: cart.errors.full_messages }, status: :unprocessable_entity
      end
    end
  end

  # POST /cart/new
  # Params: product_id, quantity
  # Adds a CartItem to current user's cart (or updates quantity if exists)
  def add_item
    product = Product.find_by(id: cart_item_params[:product_id])
    return render json: { error: 'Product not found' }, status: :not_found unless product

    qty = (cart_item_params[:quantity] || 1).to_i
    return render json: { error: 'Invalid quantity' }, status: :unprocessable_entity if qty <= 0

    cart = @current_user.cart || Cart.create!(user: @current_user)

    cart_item = cart.cart_items.find_by(product_id: product.id)
    new_qty = cart_item ? (cart_item.quantity + qty) : qty

    unless product.available?(new_qty)
      return render json: { error: 'Insufficient stock' }, status: :unprocessable_entity
    end

    CartItem.transaction do
      cart_item ||= cart.cart_items.build(product: product)
      cart_item.quantity = new_qty
      cart_item.save!
    end

    render json: serialize_cart(cart.reload), status: :ok
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  # GET /cart
  # Returns current user's Cart (with user and cart_items)
  def show
    cart = @current_user.cart
    return render json: { error: 'Cart not found' }, status: :not_found unless cart
    render json: serialize_cart(cart)
  end

  # PATCH /cart/item
  # Params: product_id, quantity
  # Update the quantity of a product already in the cart (or remove if quantity == 0)
  def update_item
    product = Product.find_by(id: cart_item_params[:product_id])
    return render json: { error: 'Product not found' }, status: :not_found unless product

    qty = (cart_item_params[:quantity] || 0).to_i
    return render json: { error: 'Invalid quantity' }, status: :unprocessable_entity if qty < 0

    cart = @current_user.cart
    return render json: { error: 'Cart not found' }, status: :not_found unless cart

    cart_item = cart.cart_items.find_by(product_id: product.id)
    return render json: { error: 'Cart item not found' }, status: :not_found unless cart_item

    if qty == 0
      cart_item.destroy
      return render json: serialize_cart(cart.reload), status: :ok
    end

    unless product.available?(qty)
      return render json: { error: 'Insufficient stock' }, status: :unprocessable_entity
    end

    cart_item.quantity = qty
    if cart_item.save
      render json: serialize_cart(cart.reload), status: :ok
    else
      render json: { error: cart_item.errors.full_messages }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  # DELETE /cart/item
  # Params: product_id (query param or in body under cart_item.product_id)
  # Removes a product from the current user's cart
  def remove_item
    product_id = params[:product_id] || cart_item_params[:product_id]
    return render json: { error: 'Product id required' }, status: :bad_request unless product_id

    cart = @current_user.cart
    return render json: { error: 'Cart not found' }, status: :not_found unless cart

    cart_item = cart.cart_items.find_by(product_id: product_id)
    return render json: { error: 'Cart item not found' }, status: :not_found unless cart_item

    cart_item.destroy
    render json: serialize_cart(cart.reload), status: :ok
  end

  # DELETE /cart
  # Clears the whole cart by destroying the Cart object itself
  def destroy
    cart = @current_user.cart
    return head :no_content unless cart

    cart.destroy
    head :no_content
  end

  private
  def serialize_cart(cart)
    {
      id: cart.id,
      user: cart.user.as_json(only: [:id, :email, :name]),
      items: cart.cart_items.map do |ci|
        {
          product: ci.product.as_json(only: [:id, :name, :price, :stock]),
          quantity: ci.quantity
        }
      end,
      total: (cart.respond_to?(:total) ? cart.total : nil)
    }
  end
  
  def cart_item_params
    params.require(:cart_item).permit(:product_id, :quantity)
  end
end
