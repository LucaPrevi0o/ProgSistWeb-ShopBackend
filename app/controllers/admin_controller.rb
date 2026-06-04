class AdminController < ApplicationController
  before_action :require_admin!

  def me
    render json: {
      id: @current_user.id,
      email: @current_user.email,
      role: @current_user.role
    }
  end
end
