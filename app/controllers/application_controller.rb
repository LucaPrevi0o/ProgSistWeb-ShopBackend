class ApplicationController < ActionController::API
  include ApiRequestParams

  before_action :authenticate_request!

  private

  def authenticate_request!
    # Require Authorization header with Bearer token for every protected request.
    header = request.headers['Authorization'] || request.authorization
    return render_unauthorized unless header.present?

    token = header.to_s.split('