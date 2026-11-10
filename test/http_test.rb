require_relative "test_helper"

class HttpTest < ApiTest
  def gunzip(body)
    Zlib::GzipReader.new(StringIO.new(body)).read
  end

  def test_gzip_cuando_el_cliente_lo_pide
    header "Accept-Encoding", "gzip"
    post_json "/auth", username: "admin", password: "secret"

    assert_equal "gzip", last_response.headers["content-encoding"]
    assert_match(/Accept-Encoding/i, last_response.headers["vary"])
    assert JSON.parse(gunzip(last_response.body)).key?("token")
  end

  def test_sin_gzip_si_el_cliente_no_lo_pide
    post_json "/auth", username: "admin", password: "secret"

    assert_nil last_response.headers["content-encoding"]
    assert JSON.parse(last_response.body).key?("token")
  end

  def test_gzip_tambien_en_el_401
    header "Accept-Encoding", "gzip"
    get "/products"

    assert_equal 401, last_response.status
    assert_equal "gzip", last_response.headers["content-encoding"]
  end

  def test_openapi_estatico_publico_y_sin_cache
    get "/openapi.yaml"

    assert_equal 200, last_response.status
    assert_equal "no-store", last_response.headers["cache-control"]
    assert_match(/\Aopenapi: 3\.0\.3/, last_response.body)
  end

  def test_authors_estatico_cacheado_24hs
    get "/AUTHORS"

    assert_equal 200, last_response.status
    assert_equal "public, max-age=86400", last_response.headers["cache-control"]
    assert_match(/text\/plain/, last_response.headers["content-type"])
    assert_includes last_response.body.dup.force_encoding("UTF-8"), "Yanina Emiliana Nuñez Gonzalez"
  end

  def test_authors_comprimido_si_se_pide
    header "Accept-Encoding", "gzip"
    get "/AUTHORS"

    assert_equal "gzip", last_response.headers["content-encoding"]
    assert_includes gunzip(last_response.body).force_encoding("UTF-8"), "Nuñez"
  end
end
