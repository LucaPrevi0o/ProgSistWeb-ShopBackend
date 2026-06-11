class UserController < ApplicationController
  skip_before_action :authenticate_request!, only: [:create]

  def create
    email = params[:email].to_s
    password = params[:password].to_s

    return render json: { error: 'Missing email or password' }, status: :unprocessable_entity if email.blank? || password.blank?
    return render json: { error: 'Email already taken' }, status: :conflict if User.exists?(email: email)

    user = User.create!(email: email, password: password)
    Carts::FindOrCreate.call(user: user)

    render json: UserSerializer.call(user, token: Auth::Token.issue(user)), status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: 'Validation failed', details: e.record.errors.full_messages }, status: :unprocessable_entity
  rescue StandardError => e
    Rails.logger.error("UserController#create error: #{e.class} - #{e.message}\n#{e.backtrace.first(10).join("\n")}")
    render json: { error: 'Internal server error' }, status: :internal_server_error
  end

  def index
    users = User.includes(user_info: [:personal_data, :payment_methods]).all
    render json: users.map { |user| UserSerializer.call(user) }
  end

  def show
    user = User.includes(user_info: [:personal_data, :payment_methods]).find_by(id: params[:id])
    return render json: { error: 'User not found' }, status: :not_found unless user

    render json: UserSerializer.call(user)
  end

  def update_info
    return render json: { error: 'Accesso non autorizzato' }, status: :unauthorized unless current_user&.id == params[:id].to_i

    Users::UpsertUserInfo.call(user: current_user, params: normalized_resource(:user_info))
    current_user.reload

    render json: UserSerializer.call(current_user)
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: 'Validation failed', details: e.record.errors.full_messages }, status: :unprocessable_entity
  end
end
