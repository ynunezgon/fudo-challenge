module Fudo
  class ProductWorker
    def initialize(products:, jobs:, delay: 5, logger: nil)
      @products = products
      @jobs = jobs
      @delay = delay
      @logger = logger
      @queue = Queue.new
      @thread = nil
    end

    attr_reader :delay

    def enqueue(name)
      job = @jobs.create(name: name, ready_at: Time.now + @delay)
      @queue << job[:id]
      job
    end

    def start
      return self if running?

      @thread = Thread.new { run_loop }
      @thread.name = "product-worker" if @thread.respond_to?(:name=)
      self
    end

    def running?
      @thread&.alive? || false
    end

    def stop
      @queue << :stop
      @thread&.join(1)
    end

    private

    def run_loop
      loop do
        job_id = @queue.pop # bloquea hasta que haya trabajo
        break if job_id == :stop

        process(job_id)
      end
    end

    def process(job_id)
      job = @jobs.find(job_id)
      return unless job

      # La espera se cuenta desde que llegó el pedido.
      wait = job[:ready_at] - Time.now
      sleep(wait) if wait.positive?

      product = @products.add(job[:name])
      @jobs.complete(job_id, product_id: product[:id])
    rescue StandardError => e
      @logger&.error("job #{job_id} falló: #{e.message}")
      @jobs.fail(job_id, e.message)
    end
  end
end
