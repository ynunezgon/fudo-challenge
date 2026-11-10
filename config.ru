require_relative "app/application"

# PRODUCT_DELAY permite acortar la espera en desarrollo; por defecto, 5 segundos.
run Fudo.build_app(delay: Float(ENV.fetch("PRODUCT_DELAY", "5")))
