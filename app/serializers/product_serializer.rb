class ProductSerializer
  def self.call(product, include_timestamps: false)
    payload = {
      id: product.id,
      name: product.name,
      description: product.description,
      category: product.category,
      price: product.price,
      stock: product.stock
    }

    if include_timestamps
      payload[:created_at] = product.created_at
      payload[:updated_at] = product.updated_at
    end

    ApiKeyTransform.camelize_keys(payload)
  end
end
