class UserController < ApplicationController
  def index
    users = User.includes(:user_info).all
    render json: users.as_json(include: { user_info: { except: [:id, :user_id] } })
  end

  def show
    user = User.includes(:user_info).find_by(id: params[:id])
    if user
      render json: user.as_json(include: { user_info: { except: [:id, :user_id] } })
    else
      render json: { error: "User not found" }, status: :not_found
    end
  end
end
