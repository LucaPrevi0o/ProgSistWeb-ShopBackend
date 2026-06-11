class UserSerializer
  def self.call(user, token: nil, include_timestamps: false)
    payload = {
      id: user.id,
      email: user.email,
      role: user.role,
      user_info: UserInfoSerializer.call(user.user_info)
    }

    payload[:token] = token if token

    if include_timestamps
      payload[:created_at] = user.created_at if user.respond_to?(:created_at)
      payload[:updated_at] = user.updated_at if user.respond_to?(:updated_at)
    end

    ApiKeyTransform.camelize_keys(payload)
  end
end
