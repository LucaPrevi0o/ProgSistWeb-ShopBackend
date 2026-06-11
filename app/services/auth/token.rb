module Auth
  class Token
    def self.issue(user)
      payload = {
        user_id: user.id,
        role: user.role,
        exp: 24.hours.from_now.to_i,
        jti: SecureRandom.uuid
      }

      JWT.encode(payload, secret, 'HS256')
    end

    def self.secret
      Rails.application.credentials.secret_key_base || Rails.application.secret_key_base
    end
  end
end
