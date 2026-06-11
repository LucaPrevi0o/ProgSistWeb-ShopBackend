class PersonalDataSerializer
  def self.call(personal_data)
    return nil unless personal_data

    ApiKeyTransform.camelize_keys({
      first_name: personal_data.first_name,
      last_name: personal_data.last_name,
      phone: personal_data.phone,
      address: AddressSerializer.call(personal_data.address)
    })
  end

  def self.snapshot(value)
    ApiKeyTransform.camelize_keys(value || {})
  end
end
