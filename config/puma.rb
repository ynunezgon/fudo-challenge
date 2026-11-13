# El estado en memoria se comparte entre hilos, no entre procesos.
workers 0

threads_count = Integer(ENV.fetch("PUMA_THREADS", 5))
threads threads_count, threads_count

port Integer(ENV.fetch("PORT", 9292))
environment ENV.fetch("RACK_ENV", "development")
