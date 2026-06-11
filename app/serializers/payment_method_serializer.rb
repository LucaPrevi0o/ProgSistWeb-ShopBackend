class PaymentMethodSerializer
  def self.call(payment_method)
    return nil unless payment_method

    ApiKeyTransform.camelize_keys({
      id: payment_method.id,
      method_type: payment_method.method_type,
      details: payment_method.details || {}
    })
  end

  def self.snapshot(value)
    ApiKeyTransform.camelize_keys(value || {})
  end
end
