class ApplicationController < ActionController::API
  include ApiRequestParams

  before_action :authenticate_request!

  private

  def authenticate_request!
    header = request.headers['Authorization'] || request.authorization
    return render_unauthorized unless header.present?

    token = header.to_s.split(' ').last

    begin
      secret = Rails.application.credentials.secret_key_base || Rails.application.secret_key_base
      decoded = JWT.decode(token, secret, true, { algorithm: 'HS256' })
      payload = decoded[0]
      @current_user = User.find_by(id: payload['user_id'])
      return render_unauthorized unless @current_user
    rescue JWT::ExpiredSignature
      render json: { error: 'Token scaduto' }, status: :unauthorized
    rescue JWT::DecodeError
      render json: { error: 'Token non valido' }, status: :unauthorized
    end
  end

  def require_admin!
    return if @current_user&.admin?

    render json: { error: 'Accesso riservato agli amministratori' }, status: :forbidden
  end

  def current_user
    @current_user
  end

  def render_unauthorized
    response.headers['WWW-Authenticate'] = 'Bearer realm="Application"'
    render json: { error: 'Accesso non autorizzato' }, status: :unauthorized
  end
end
