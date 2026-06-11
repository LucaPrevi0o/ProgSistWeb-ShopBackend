class AdminController < ApplicationController
  before_action :require_admin!

  def me
    render json: UserSerializer.call(current_user)
  end
end
