class AuthController < ApplicationController
  
  skip_before_action :authenticate_request!, only: [:login]

  def login
    begin
      email = params[:email].to_s
      password = params[:password].to_s

      user = User.find_by(email: email)
      if user&.authenticate(password)
        payload = { user_id: user.id, exp: 24.hours.from_now.to_i, jti: SecureRandom.uuid }
        secret = Rails.application.credentials.secret_key_base || Rails.application.secret_key_base
        token = JWT.encode(payload, secret, 'HS256')
        render json: { token: token }
      else
        render json: { error: 'Invalid credentials' }, status: :unauthorized
      end
    rescue => e
      Rails.logger.error("AuthController#login error: #{e.class} - #{e.message}\n#{e.backtrace.first(10).join("\n")}")
      render json: { error: 'Internal server error' }, status: :internal_server_error
    end
  end
end
