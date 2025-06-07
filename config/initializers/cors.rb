Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins 'http://localhost:3000', 'http://localhost:3001', /.*\.serveo\.net/  # acepta localhost y cualquier subdominio de serveo.net

    resource '*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: true  # solo si usas cookies/sesiones
  end
end

