require "json"
require "time"
require "rack"

module Fudo
  class API
    JSON_HEADERS = { "content-type" => "application/json" }.freeze
    MAX_NAME_LENGTH = 255

    def initialize(tokens:, products:, jobs:, worker:, users:)
      @tokens = tokens
      @products = products
      @jobs = jobs
      @worker = worker
      @users = users
    end

    def call(env)
      req = Rack::Request.new(env)

      case [req.request_method, req.path_info]
      in ["POST", "/auth"]               then authenticate(req)
      in ["GET", "/products"]            then list_products
      in ["POST", "/products"]           then create_product(req)
      in ["GET", %r{\A/jobs/([\w-]+)\z}]  then show_job(Regexp.last_match(1))
      in [_, "/auth" | "/products"]      then error(405, "method_not_allowed")
      else error(404, "not_found")
      end
    rescue JSON::ParserError
      error(400, "bad_request", "El body debe ser JSON válido.")
    end

    private

    def authenticate(req)
      data = parse_json(req)
      username = data["username"]
      password = data["password"]

      unless username.is_a?(String) && password.is_a?(String)
        return error(400, "bad_request", "Se requieren username y password.")
      end

      return error(401, "invalid_credentials") unless valid_credentials?(username, password)

      token = @tokens.issue(username)
      json(200, token: token, token_type: "Bearer", expires_in: @tokens.ttl)
    end

    def list_products
      json(200, data: @products.all)
    end

    def create_product(req)
      name = parse_json(req)["name"]
      name = name.strip if name.is_a?(String)

      if !name.is_a?(String) || name.empty? || name.length > MAX_NAME_LENGTH
        return error(422, "invalid_name", "name es obligatorio (texto de 1 a #{MAX_NAME_LENGTH} caracteres).")
      end

      job = @worker.enqueue(name)
      location = "/jobs/#{job[:id]}"
      json(202, job_payload(job), "location" => location)
    end

    def show_job(id)
      job = @jobs.find(id)
      job ? json(200, job_payload(job)) : error(404, "not_found")
    end

    def job_payload(job)
      {
        job_id: job[:id],
        status: job[:status],
        product_id: job[:product_id],
        estimated_ready_at: job[:ready_at].utc.iso8601
      }.tap { |p| p[:error] = job[:error] if job[:error] }
    end

    def valid_credentials?(username, password)
      expected = @users[username]
      !expected.nil? && Rack::Utils.secure_compare(expected, password)
    end

    def parse_json(req)
      raw = req.body&.read.to_s
      return {} if raw.strip.empty?

      data = JSON.parse(raw)
      raise JSON::ParserError, "se esperaba un objeto" unless data.is_a?(Hash)

      data
    end

    def json(status, payload, extra_headers = {})
      [status, JSON_HEADERS.merge(extra_headers), [JSON.generate(payload)]]
    end

    def error(status, code, message = nil)
      payload = { error: code }
      payload[:message] = message if message
      json(status, payload)
    end
  end
end
