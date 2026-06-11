# frozen_string_literal: true

# Converts keys between the Angular-facing camelCase API contract and
# Rails-friendly snake_case internals.
#
# Important boundary rule:
# PaymentMethod.details is an opaque JSON payload shared with Angular, so its
# nested keys must be preserved exactly as received/stored. For example,
# details.cardHolderName must not become details.card_holder_name.
module ApiKeyTransform
  OPAQUE_KEYS = %w[details].freeze

  module_function

  def underscore_keys(value, preserve_keys: OPAQUE_KEYS)
    transform_keys(value, key_transform: :underscore, preserve_keys: preserve_keys)
  end

  def camelize_keys(value, preserve_keys: OPAQUE_KEYS)
    transform_keys(value, key_transform: :camelize_lower, preserve_keys: preserve_keys)
  end

  def transform_keys(value, key_transform:, preserve_keys: OPAQUE_KEYS)
    normalized_value = normalize_value(value)

    case normalized_value
    when Array
      normalized_value.map do |item|
        transform_keys(item, key_transform: key_transform, preserve_keys: preserve_keys)
      end
    when Hash
      normalized_value.each_with_object({}) do |(key, nested_value), transformed_hash|
        transformed_key = transform_key(key, key_transform)

        transformed_hash[transformed_key] = if opaque_key?(key, transformed_key, preserve_keys)
          nested_value
        else
          transform_keys(nested_value, key_transform: key_transform, preserve_keys: preserve_keys)
        end
      end
    else
      normalized_value
    end
  end

  def normalize_value(value)
    if defined?(ActionController::Parameters) && value.is_a?(ActionController::Parameters)
      value.to_unsafe_h
    else
      value
    end
  end

  def transform_key(key, key_transform)
    transformed = case key_transform
                  when :underscore
                    key.to_s.underscore
                  when :camelize_lower
                    key.to_s.camelize(:lower)
                  else
                    raise ArgumentError, "Unknown key transform: #{key_transform.inspect}"
                  end

    key.is_a?(Symbol) ? transformed.to_sym : transformed
  end

  def opaque_key?(original_key, transformed_key, preserve_keys)
    preserved = preserve_keys.map(&:to_s)

    preserved.include?(original_key.to_s) || preserved.include?(transformed_key.to_s)
  end
end
