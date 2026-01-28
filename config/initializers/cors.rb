# Be sure to restart your server when you modify this file.
# Configure CORS to allow requests from the frontend dev server.
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins 'http://localhost:4200'
    resource '*',
      headers: :any,
      methods: %i[get post put patch delete options head]
  end
end
