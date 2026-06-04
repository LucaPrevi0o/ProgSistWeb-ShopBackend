class UserController < ApplicationController
  skip_before_action :authenticate_request!, only: [:create]

  # Public endpoint to register a new user. Returns JWT token on success.
  def create
    begin
      email = params[:email].to_s
      password = params[:password].to_s

      if email.blank? || password.blank?
        render json: { error: 'Missing email or password' }, status: :unprocessable_entity and return
      end

      if User.exists?(email: email)
        render json: { error: 'Email already taken' }, status: :conflict and return
      end

      user = User.create!(email: email, password: password)

      payload = { user_id: user.id, exp: 24.hours.from_now.to_i, jti: SecureRandom.uuid }
      secret = Rails.application.credentials.secret_key_base || Rails.application.secret_key_base
      token = JWT.encode(payload, secret, 'HS256')

      render json: { token: token, id: user.id }, status: :created
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: 'Validation failed', details: e.record.errors.full_messages }, status: :unprocessable_entity
    rescue => e
      Rails.logger.error("UserController#create error: #{e.class} - #{e.message}\n#{e.backtrace.first(10).join("\n")}")
      render json: { error: 'Internal server error' }, status: :internal_server_error
    end
  end
  def index
    users = User.includes(user_info: [:payment_methods]).all
    payload = users.map { |u| build_user_payload(u) }
    render json: payload
  end

  def show
    user = User.includes(user_info: [:payment_methods]).find_by(id: params[:id])
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

    data_attrs = extract_info_data
    address_attrs = extract_address_attributes

    begin
      ActiveRecord::Base.transaction do
        data_attrs = data_attrs.merge('address' => address_attrs) if address_attrs.present?
        info = @current_user.build_user_info(data: data_attrs)
        info.save!
        # Accept optional paymentMethods array in info and create payment records
        if params[:info].present?
          pm_list = params[:info][:paymentMethods] || params[:info][:payment_methods]
          if pm_list.present?
            pm_list.each do |pm|
              t = pm[:type] || pm['type']
              details = pm[:details] || pm['details']
              next if t.blank? || details.blank?
              info.payment_methods.create!(type: t, details: details)
            end
          end
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
    data_attrs = extract_info_data
    address_attrs = extract_address_attributes

    begin
      ActiveRecord::Base.transaction do
        info = @current_user.user_info
        if info
          new_data = (info.data || {}).merge(data_attrs)
          new_data = new_data.merge('address' => address_attrs) if address_attrs.present?
          info.update!(data: new_data)
        else
          data_attrs = data_attrs.merge('address' => address_attrs) if address_attrs.present?
          info = @current_user.create_user_info!(data: data_attrs)
        end

        # If paymentMethods are provided in the info payload, replace existing methods
        if params[:info].present?
          pm_list = params[:info][:paymentMethods] || params[:info][:payment_methods]
          if pm_list.present?
            # simple strategy: remove existing methods and recreate from payload
            info.payment_methods.destroy_all
            pm_list.each do |pm|
              t = pm[:type] || pm['type']
              details = pm[:details] || pm['details']
              next if t.blank? || details.blank?
              info.payment_methods.create!(type: t, details: details)
            end
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
    # Accept nested `info.data.address` (camelCase or snake_case), or `info.address`, or top-level fields
    if params[:info].present?
      info = params[:info]
      data = info[:data] || info
      if data[:address].present?
        a = data[:address]
        return {
          'street' => a[:street] || a['street'],
          'city' => a[:city] || a['city'],
          'postal_code' => a[:postalCode] || a[:postal_code] || a['postalCode'] || a['postal_code'],
          'country' => a[:country] || a['country']
        }.compact
      end
    end

    # fallback to top-level permitted params
    params.permit(:street, :city, :postal_code, :country).to_h.symbolize_keys
  end

  def extract_info_data
    # Return a hash suitable to store in `user_info.data` using snake_case keys.
    if params[:info].present?
      i = params[:info]
      data = i[:data] || i
      return {
        'first_name' => data[:firstName] || data[:first_name],
        'last_name' => data[:lastName] || data[:last_name],
        'phone' => data[:phone]
      }.compact
    end

    # fallback to top-level permitted params
    p = user_info_params.to_h.symbolize_keys
    {
      'first_name' => p[:first_name],
      'last_name' => p[:last_name],
      'phone' => p[:phone]
    }.compact
  end

  def build_user_payload(user)
    info = nil
    if user.user_info
      d = (user.user_info.data || {}).with_indifferent_access
      info = { data: {} }
      info[:data][:firstName] = d['first_name'] || d['firstName']
      info[:data][:lastName] = d['last_name'] || d['lastName']
      info[:data][:phone] = d['phone']

      addr = d['address'] || {}
      if addr.present?
        info[:data][:address] = {
          street: addr['street'],
          city: addr['city'],
          postalCode: addr['postal_code'] || addr['postalCode'],
          country: addr['country']
        }
      end

      if user.user_info.payment_methods.present?
        info[:paymentMethods] = user.user_info.payment_methods.map do |pm|
          {
            id: pm.id,
            type: pm.type,
            details: pm.details
          }
        end
      end
    end

    {
      id: user.id,
      email: user.email,
      info: info
    }
  end
end
