require "json"

module Fudo
  # Corta con 401 cualquier request a rutas protegidas sin un Bearer token válido.
  class AuthMiddleware
    PROTECTED_PREFIXES = ["/products", "/jobs"].freeze

    def initialize(app, tokens:)
      @app = app
      @tokens = tokens
    end

    def call(env)
      return @app.call(env) unless protected_path?(env["PATH_INFO"])
      return @app.call(env) if @tokens.valid?(bearer_token(env))

      body = JSON.generate(error: "unauthorized", message: "Falta un token válido. Obtenelo en POST /auth.")
      [
        401,
        {
          "content-type" => "application/json",
          "www-authenticate" => 'Bearer realm="fudo-api"'
        },
        [body]
      ]
    end

    private

    def protected_path?(path)
      PROTECTED_PREFIXES.any? { |prefix| path == prefix || path.start_with?("#{prefix}/") }
    end

    def bearer_token(env)
      header = env["HTTP_AUTHORIZATION"].to_s
      scheme, token = header.split(" ", 2)
      return nil unless scheme&.casecmp?("Bearer")

      token&.strip
    end
  end
end
