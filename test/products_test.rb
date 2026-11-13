require_relative "test_helper"

class ProductsTest < ApiTest
  def setup
    login!
  end

  def test_creacion_responde_202_con_job_y_location
    post_json "/products", name: "Pizza"

    assert_equal 202, last_response.status
    assert_equal "pending", json_body["status"]
    assert_nil json_body["product_id"]
    assert_equal "/jobs/#{json_body['job_id']}", last_response.headers["location"]
  end

  def test_el_producto_no_existe_hasta_que_pasa_el_delay
    post_json "/products", name: "Empanada"
    job_url = last_response.headers["location"]

    get "/products"
    assert_empty json_body["data"], "no debería estar disponible al instante"

    sleep TEST_DELAY + 0.3

    get "/products"
    assert_equal [{ "id" => 1, "name" => "Empanada" }], json_body["data"]

    get job_url
    assert_equal "completed", json_body["status"]
    assert_equal 1, json_body["product_id"]
  end

  def test_pedidos_simultaneos_quedan_listos_juntos
    started = Time.now
    10.times { |i| post_json "/products", name: "Producto #{i}" }

    sleep TEST_DELAY + 0.3
    get "/products"

    assert_equal 10, json_body["data"].size
    assert_equal (1..10).to_a, json_body["data"].map { |p| p["id"] }
    assert_operator Time.now - started, :<, TEST_DELAY * 3
  end

  def test_nombre_invalido
    post_json "/products", name: "   "
    assert_equal 422, last_response.status

    post_json "/products", {}
    assert_equal 422, last_response.status

    post_json "/products", name: 123
    assert_equal 422, last_response.status
  end

  def test_job_inexistente
    get "/jobs/no-existe"

    assert_equal 404, last_response.status
  end

  def test_ruta_inexistente
    get "/nada"

    assert_equal 404, last_response.status
  end
end
