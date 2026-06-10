# app/controllers/admin/users_controller.rb

module Admin

  class UsersController < ApplicationController

    before_action :require_admin!
    before_action :set_user, only: [:show]

    def index

      users = User.order(:id)

      render json: users.map { |user|
        serialize_user(user)
      }

    end

    def show
      render json: serialize_user(@user)
    end

    private

    def set_user

      @user = User.find_by(id: params[:id])

      return render(
        json: { error: 'User not found' },
        status: :not_found
      ) unless @user

    end

    def serialize_user(user)
      info_data = user.user_info&.data || {}

      {
        id: user.id,
        email: user.email,
        role: user.respond_to?(:role) ? user.role : nil,
        createdAt: user.respond_to?(:created_at) ? user.created_at : nil,

        info: user.user_info ? {
          firstName: info_data["firstName"] || info_data["first_name"],
          lastName: info_data["lastName"] || info_data["last_name"],
          phone: info_data["phone"]
        } : nil
      }
    end

  end

end