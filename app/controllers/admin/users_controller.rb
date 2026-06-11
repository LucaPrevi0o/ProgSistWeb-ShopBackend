module Admin
  class UsersController < ApplicationController
    before_action :require_admin!
    before_action :set_user, only: [:show]

    def index
      users = User.includes(user_info: [:personal_data, :payment_methods]).where(role: 'USER').order(:id)
      render json: users.map { |user| UserSerializer.call(user, include_timestamps: true) }
    end

    def show
      render json: UserSerializer.call(@user, include_timestamps: true)
    end

    private

    def set_user
      @user = User.includes(user_info: [:personal_data, :payment_methods]).find_by(id: params[:id])
      return render json: { error: 'User not found' }, status: :not_found unless @user
    end
  end
end
