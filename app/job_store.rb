require "securerandom"

module Fudo
  class JobStore
    def initialize
      @jobs = {}
      @mutex = Mutex.new
    end

    def create(name:, ready_at:)
      job = {
        id: SecureRandom.uuid,
        status: "pending",
        name: name,
        product_id: nil,
        error: nil,
        ready_at: ready_at
      }
      @mutex.synchronize { @jobs[job[:id]] = job }
      job.dup
    end

    def find(id)
      @mutex.synchronize { @jobs[id]&.dup }
    end

    def complete(id, product_id:)
      update(id, status: "completed", product_id: product_id)
    end

    def fail(id, message)
      update(id, status: "failed", error: message)
    end

    private

    def update(id, **attrs)
      @mutex.synchronize do
        job = @jobs[id]
        job&.merge!(attrs)
      end
    end
  end
end
