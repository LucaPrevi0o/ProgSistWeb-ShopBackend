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

      {
        id: user.id,
        email: user.email,
        role: user.role,
        createdAt: user.created_at,

        info: user.info ? {
          firstName: user.info.first_name,
          lastName: user.info.last_name,
          phone: user.info.phone
        } : nil
      }

    end

  end

end