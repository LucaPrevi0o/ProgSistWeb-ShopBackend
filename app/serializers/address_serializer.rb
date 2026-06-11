class AddressSerializer
  def self.call(address)
    return nil unless address

    ApiKeyTransform.camelize_keys({
      street: address.street,
      city: address.city,
      postal_code: address.postal_code,
      country: address.country
    })
  end
end
