class UserController < ApplicationController
  def index
    users = User.includes(user_info: :user_address).all
    payload = users.map do |u|
      build_user_payload(u)
    end
    render json: payload
  end

  def show
    user = User.includes(user_info: :user_address).find_by(id: params[:id])
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
    address_attrs = extract_address_attributes

    begin
      ActiveRecord::Base.transaction do
        info = @current_user.build_user_info(attrs)
        info.save!
        if address_attrs.present?
          info.create_user_address!(address_attrs)
        end
      end
      render json: build_user_payload(@current_user)
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: 'Validation failed', details: e.record.errors.full_messages }, status: :unprocessable_entity
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
    address_attrs = extract_address_attributes

    begin
      ActiveRecord::Base.transaction do
        info.update!(attrs)
        if address_attrs.present?
          if info.user_address
            info.user_address.update!(address_attrs)
          else
            info.create_user_address!(address_attrs)
          end
        end
      end
      render json: build_user_payload(@current_user)
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: 'Validation failed', details: e.record.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def user_info_params
    params.permit(:first_name, :last_name, :phone)
  end

  def extract_address_attributes
    # Accept nested `info.address` with camelCase or snake_case, or top-level fields
    if params[:info].present? && params[:info][:address].present?
      a = params[:info][:address]
      return {
        street: a[:street] || a['street'],
        city: a[:city] || a['city'],
        postal_code: a[:postalCode] || a[:postal_code] || a['postalCode'] || a['postal_code'],
        country: a[:country] || a['country']
      }.compact
    end

    # fallback to top-level permitted params
    params.permit(:street, :city, :postal_code, :country).to_h.symbolize_keys
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
    info = nil
    if user.user_info
      info = {
        firstName: user.user_info.first_name,
        lastName: user.user_info.last_name,
        phone: user.user_info.phone
      }

      if user.user_info.user_address
        a = user.user_info.user_address
        info[:address] = {
          street: a.street,
          city: a.city,
          postalCode: a.postal_code,
          country: a.country
        }
      end
    end

    {
      id: user.id,
      email: user.email,
      info: info
    }
  end
end
