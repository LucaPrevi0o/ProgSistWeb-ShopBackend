class AuthController < ApplicationController
  skip_before_action :authenticate_request!, only: [:login]

  def login
    user = User.includes(user_info: [:personal_data, :payment_methods]).find_by(email: params[:email].to_s)

    if user&.authenticate(params[:password].to_s)
      render json: UserSerializer.call(user, token: Auth::Token.issue(user))
    else
      render json: { error: 'Invalid credentials' }, status: :unauthorized
    end
  rescue StandardError => e
    Rails.logger.error("AuthController#login error: #{e.class} - #{e.message}\n#{e.backtrace.first(10).join("\n")}")
    render json: { error: 'Internal server error' }, status: :internal_server_error
  end
end
