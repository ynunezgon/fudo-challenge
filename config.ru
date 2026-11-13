require_relative "app/application"

run Fudo.build_app(delay: Float(ENV.fetch("PRODUCT_DELAY", "5")))
