class UserController < ApplicationController
  def index
    users = User.includes(:user_info).all
    payload = users.map do |u|
      build_user_payload(u)
    end
    render json: payload
  end

  def show
    user = User.includes(:user_info).find_by(id: params[:id])
    if user
      render json: build_user_payload(user)
    else
      render json: { error: "User not found" }, status: :not_found
    end
  end

  # Create user info for the current user (accepts either top-level fields or nested `info`)
  def create_info
    return render json: { error: 'Accesso non autorizzato' }, status: :unauthorized unless @current_user && @current_user.id == params[:id].to_i

    if @current_user.user_info.present?
      render json: { error: 'User info already present' }, status: :conflict
      return
    end

    attrs = extract_info_attributes
    info = @current_user.build_user_info(attrs)
    if info.save
      render json: build_user_payload(@current_user)
    else
      render json: { error: 'Validation failed', details: info.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # Update existing user info
  def update_info
    return render json: { error: 'Accesso non autorizzato' }, status: :unauthorized unless @current_user && @current_user.id == params[:id].to_i

    info = @current_user.user_info
    unless info
      render json: { error: 'User info not found' }, status: :not_found
      return
    end

    attrs = extract_info_attributes
    if info.update(attrs)
      render json: build_user_payload(@current_user)
    else
      render json: { error: 'Validation failed', details: info.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def user_info_params
    params.permit(:first_name, :last_name, :phone)
  end

  def extract_info_attributes
    # Support either nested `info` with camelCase or snake_case, or top-level snake_case fields
    if params[:info].present?
      i = params[:info]
      return {
        first_name: i[:firstName] || i[:first_name],
        last_name: i[:lastName] || i[:last_name],
        phone: i[:phone]
      }
    end

    # fallback to top-level permitted params
    user_info_params.to_h.symbolize_keys
  end

  def build_user_payload(user)
    info = user.user_info ? {
      firstName: user.user_info.first_name,
      lastName: user.user_info.last_name,
      phone: user.user_info.phone
    } : nil

    {
      id: user.id,
      email: user.email,
      info: info
    }
  end
end
