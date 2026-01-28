class ApplicationController < ActionController::Base
  
  allow_browser versions: :modern
  stale_when_importmap_changes
  before_action :authenticate_request!

  private

  def authenticate_request!

    header = request.headers['Authorization']
    token = header&.split(' ')&.last
    return render_unauthorized unless token

    begin
      secret = Rails.application.credentials.secret_key_base || Rails.application.secret_key_base
      decoded = JWT.decode(token, secret, true, algorithm: 'HS256')
      payload = decoded[0]
      @current_user = User.find_by(id: payload['user_id'])
      return render_unauthorized unless @current_user
    rescue JWT::ExpiredSignature
      render json: { error: 'Token scaduto' }, status: :unauthorized
    rescue JWT::DecodeError
      render json: { error: 'Token non valido' }, status: :unauthorized
    end
  end

  def render_unauthorized
    render json: { error: 'Accesso non autorizzato' }, status: :unauthorized
  end
end
