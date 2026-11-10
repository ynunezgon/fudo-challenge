# Un solo proceso a propósito: tokens, productos y jobs viven en memoria.
# Con workers > 0 cada proceso tendría su propia copia del estado y un token
# emitido por un proceso no sería válido en otro. Para escalar horizontalmente
# habría que mover el estado a Redis o a una base de datos.
workers 0

threads_count = Integer(ENV.fetch("PUMA_THREADS", 5))
threads threads_count, threads_count

port Integer(ENV.fetch("PORT", 9292))
environment ENV.fetch("RACK_ENV", "development")
