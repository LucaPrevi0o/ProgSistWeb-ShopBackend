class UserInfoSerializer
  def self.call(user_info)
    return nil unless user_info

    ApiKeyTransform.camelize_keys({
      data: PersonalDataSerializer.call(user_info.personal_data),
      payment_methods: user_info.payment_methods.map { |payment_method| PaymentMethodSerializer.call(payment_method) }
    })
  end
end
