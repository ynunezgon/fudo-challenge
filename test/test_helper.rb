require "minitest/autorun"
require "rack/test"
require "json"
require "zlib"
require "stringio"
require_relative "../app/application"

# Delay corto para que los tests no esperen 5 segundos.
TEST_DELAY = 0.3

class ApiTest < Minitest::Test
  include Rack::Test::Methods

  def app
    @app ||= Fudo.build_app(delay: TEST_DELAY, users: { "admin" => "secret" })
  end

  def post_json(path, payload)
    post path, JSON.generate(payload), "CONTENT_TYPE" => "application/json"
  end

  def json_body
    JSON.parse(last_response.body)
  end

  def login!
    post_json "/auth", username: "admin", password: "secret"
    token = json_body.fetch("token")
    header "Authorization", "Bearer #{token}"
    token
  end
end
