require "rack"
require_relative "token_store"
require_relative "product_store"
require_relative "job_store"
require_relative "product_worker"
require_relative "auth_middleware"
require_relative "api"

module Fudo
  PUBLIC_DIR = File.expand_path("../public", __dir__)

  def self.build_app(delay: 5, users: default_users)
    tokens   = TokenStore.new
    products = ProductStore.new
    jobs     = JobStore.new
    worker   = ProductWorker.new(products: products, jobs: jobs, delay: delay).start

    api = API.new(tokens: tokens, products: products, jobs: jobs, worker: worker, users: users)

    Rack::Builder.new do
      use Rack::Deflater
      use Rack::Static,
          urls: ["/openapi.yaml", "/AUTHORS"],
          root: PUBLIC_DIR,
          header_rules: [
            ["/openapi.yaml", { "content-type" => "application/yaml", "cache-control" => "no-store" }],
            ["/AUTHORS", { "content-type" => "text/plain; charset=utf-8", "cache-control" => "public, max-age=86400" }]
          ]
      use AuthMiddleware, tokens: tokens
      run api
    end.to_app
  end

  def self.default_users
    { ENV.fetch("API_USER", "admin") => ENV.fetch("API_PASSWORD", "secret") }
  end
end
