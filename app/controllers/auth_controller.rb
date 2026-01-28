class AuthController < ApplicationController
  
  skip_before_action :authenticate_request!, only: [:login]

  def login

    user = User.find_by(email: params[:email])
    if user&.authenticate(params[:password])
      payload = { user_id: user.id, exp: 24.hours.from_now.to_i, jti: SecureRandom.uuid }
      secret = Rails.application.credentials.secret_key_base || Rails.application.secret_key_base
      token = JWT.encode(payload, secret, 'HS256')
      render json: { token: token }
    else
      render json: { error: 'Invalid credentials' }, status: :unauthorized
    end
  end
end
