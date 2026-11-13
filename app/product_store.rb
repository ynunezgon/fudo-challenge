module Fudo
  # Persistencia en memoria de productos. Thread-safe: la escriben el worker
  # y la leen los hilos de Puma al mismo tiempo.
  class ProductStore
    def initialize
      @products = []
      @next_id = 1
      @mutex = Mutex.new
    end

    def add(name)
      @mutex.synchronize do
        product = { id: @next_id, name: name }.freeze
        @products << product
        @next_id += 1
        product
      end
    end

    def all
      @mutex.synchronize { @products.dup }
    end

  end
end
