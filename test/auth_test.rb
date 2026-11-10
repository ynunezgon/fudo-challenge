require_relative "test_helper"

class AuthTest < ApiTest
  def test_login_ok_devuelve_token
    post_json "/auth", username: "admin", password: "secret"

    assert_equal 200, last_response.status
    assert_equal "Bearer", json_body["token_type"]
    assert_match(/\A\h{64}\z/, json_body["token"])
  end

  def test_credenciales_invalidas
    post_json "/auth", username: "admin", password: "mala"

    assert_equal 401, last_response.status
    assert_equal "invalid_credentials", json_body["error"]
  end

  def test_faltan_campos
    post_json "/auth", username: "admin"

    assert_equal 400, last_response.status
  end

  def test_json_invalido
    post "/auth", "{no es json", "CONTENT_TYPE" => "application/json"

    assert_equal 400, last_response.status
  end

  def test_productos_sin_token
    get "/products"

    assert_equal 401, last_response.status
    assert_match(/Bearer/, last_response.headers["www-authenticate"])
  end

  def test_productos_con_token_invalido
    header "Authorization", "Bearer inventado"
    get "/products"

    assert_equal 401, last_response.status
  end

  def test_jobs_tambien_protegido
    get "/jobs/cualquiera"

    assert_equal 401, last_response.status
  end

  def test_metodo_no_permitido
    get "/auth"

    assert_equal 405, last_response.status
  end
end

class TokenStoreTest < Minitest::Test
  def test_token_vencido_no_es_valido
    now = Time.now
    store = Fudo::TokenStore.new(ttl: 10, clock: -> { now })
    token = store.issue("admin")
    assert store.valid?(token)

    now += 11
    refute store.valid?(token)
  end
end
