require "securerandom"

module Fudo
  # Emite y valida tokens opacos (Bearer). Vive en memoria del proceso.
  class TokenStore
    DEFAULT_TTL = 3600 # segundos

    def initialize(ttl: DEFAULT_TTL, clock: -> { Time.now })
      @ttl = ttl
      @clock = clock
      @tokens = {}
      @mutex = Mutex.new
    end

    attr_reader :ttl

    def issue(username)
      token = SecureRandom.hex(32)
      @mutex.synchronize do
        @tokens[token] = { username: username, expires_at: @clock.call + @ttl }
      end
      token
    end

    def valid?(token)
      return false if token.nil? || token.empty?

      @mutex.synchronize do
        data = @tokens[token]
        return false unless data

        if data[:expires_at] <= @clock.call
          @tokens.delete(token) # limpieza perezosa del token vencido
          return false
        end
        true
      end
    end
  end
end
