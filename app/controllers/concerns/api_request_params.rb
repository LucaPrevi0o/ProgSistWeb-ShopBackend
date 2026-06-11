# frozen_string_literal: true

# Normalizes Angular-facing camelCase request data into Rails-friendly snake_case.
module ApiRequestParams
  extend ActiveSupport::Concern

  private

  def normalized_json_body
    ApiKeyTransform.underscore_keys(request.request_parameters)
  end

  def normalized_resource(resource_name)
    normalized_json_body.fetch(resource_name.to_s, {})
  end

  def normalized_query_params
    ApiKeyTransform.underscore_keys(request.query_parameters)
  end
end
