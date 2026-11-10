# Fudo Challenge — API de productos en Rack

API JSON hecha con Rack puro (sin Rails) que permite autenticarse, pedir la creación asíncrona de productos y consultarlos.

Autora: Yanina Emiliana Nuñez Gonzalez

## Contenido

| Archivo | Qué es |
| --- | --- |
| `fudo.md`, `tcp.md`, `http.md` | Respuestas a los puntos 1 a 3 del challenge |
| `config.ru` | Punto de entrada de Rack |
| `app/` | Código de la aplicación |
| `public/openapi.yaml` | Especificación OpenAPI 3.0 (servida en `/openapi.yaml`) |
| `public/AUTHORS` | Autora (servida en `/AUTHORS`) |
| `test/` | Tests con Minitest y rack-test |

## Cómo levantarlo

### Con Docker

```bash
docker build -t fudo-challenge .
docker run --rm -p 9292:9292 fudo-challenge
```

### Local

Requiere Ruby 3.2 o superior (el repo fija 3.3.6 en `.ruby-version`).

```bash
bundle install
bundle exec puma -C config/puma.rb
```

La API queda en `http://localhost:9292`.

### Variables de entorno

| Variable | Default | Uso |
| --- | --- | --- |
| `API_USER` | `admin` | Usuario válido para `POST /auth` |
| `API_PASSWORD` | `secret` | Contraseña de ese usuario |
| `PRODUCT_DELAY` | `5` | Segundos hasta que un producto queda disponible |
| `PORT` | `9292` | Puerto de Puma |
| `PUMA_THREADS` | `5` | Hilos de Puma |

## Tests

```bash
bundle exec rake test
```

Los tests usan un delay de 0,3 s para no esperar 5 segundos.

## Endpoints

| Método | Ruta | Auth | Respuesta |
| --- | --- | --- | --- |
| `POST` | `/auth` | No | `200` con token, `401` si las credenciales son inválidas |
| `POST` | `/products` | Sí | `202` con el job y header `Location` |
| `GET` | `/products` | Sí | `200` con los productos ya creados |
| `GET` | `/products/:id` | Sí | `200` o `404` |
| `GET` | `/jobs/:id` | Sí | `200` con el estado del pedido (`pending`, `completed`, `failed`) |
| `GET` | `/openapi.yaml` | No | Especificación, `Cache-Control: no-store` |
| `GET` | `/AUTHORS` | No | Autora, `Cache-Control: public, max-age=86400` |

## Ejemplo de punta a punta

```bash
# 1. Autenticarse
TOKEN=$(curl -s -X POST localhost:9292/auth \
  -H 'Content-Type: application/json' \
  -d '{"username":"admin","password":"secret"}' | ruby -rjson -e 'puts JSON.parse(STDIN.read)["token"]')

# 2. Pedir la creación (responde 202 con el job)
curl -i -X POST localhost:9292/products \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"name":"Pizza muzzarella"}'

# 3. Al instante todavía no está
curl -s localhost:9292/products -H "Authorization: Bearer $TOKEN"
# {"data":[]}

# 4. A los 5 segundos ya está
sleep 5
curl -s localhost:9292/products -H "Authorization: Bearer $TOKEN"
# {"data":[{"id":1,"name":"Pizza muzzarella"}]}

# 5. Respuesta comprimida si el cliente la pide
curl -s -D - -o /dev/null -H 'Accept-Encoding: gzip' \
  localhost:9292/products -H "Authorization: Bearer $TOKEN"
# Content-Encoding: gzip
```

## Arquitectura

Pipeline de middlewares, de afuera hacia adentro:

1. `Rack::Deflater` comprime con gzip todo lo que sale, sólo si el request trae `Accept-Encoding: gzip`.
2. `Rack::Static` sirve `openapi.yaml` y `AUTHORS` con su `Cache-Control`. Va antes de la autenticación porque son públicos.
3. `Fudo::AuthMiddleware` exige `Authorization: Bearer <token>` en `/products` y `/jobs`.
4. `Fudo::API` resuelve la ruta y ejecuta el handler.

La creación asíncrona separa la aceptación del pedido de su procesamiento:

1. `POST /products` valida el nombre, registra un job `pending` con `ready_at = ahora + 5 s`, lo encola y responde `202`.
2. `Fudo::ProductWorker`, un hilo de fondo, saca jobs de una `Queue`, espera hasta su `ready_at`, crea el producto y marca el job `completed`.
3. El cliente sigue el estado en `GET /jobs/:id` (la URL del header `Location`) o consulta `GET /products`.

## Decisiones y trade-offs

- **`202 Accepted` y no `201 Created`.** 201 indica que el recurso ya existe. Acá el producto se crea después, así que 202 describe lo que realmente pasa. El header `Location` apunta al recurso de estado del job.
- **Un worker con `ready_at` en vez de un `sleep(5)` por pedido.** Todos los jobs tienen el mismo delay y la cola es FIFO, así que cada uno espera sólo lo que le falta: 10 pedidos simultáneos quedan listos a los ~5 s, no a los 50, con un único hilo extra.
- **Thread-safety.** El worker y los hilos de Puma comparten los stores, así que cada store protege su estado con un `Mutex`. El GVL de Ruby no alcanza: no hace atómico un "leer `@next_id`, sumar 1, guardar".
- **Puma con `workers 0`.** El estado vive en memoria del proceso. Con varios procesos cada uno tendría su copia, y un token emitido por uno no valdría en otro.
- **Token opaco en memoria y no JWT.** Con una sola instancia es lo más simple, vence a la hora y se revoca borrándolo. JWT tiene sentido cuando varios servicios validan sin un store central.
- **Credenciales por variables de entorno y comparadas con `Rack::Utils.secure_compare`** para no exponer diferencias de tiempo.
- **`no-store` para `openapi.yaml`.** "Nunca cacheado" es `no-store`; `no-cache` permite guardar una copia si se revalida.
- **Router sin dependencias.** Con pocas rutas, pattern matching sobre método y path es más legible que sumar una gema.
- **Dependencias por constructor** (`Fudo.build_app`). Los tests arman la misma app que `config.ru`, con un delay corto.

## Cómo lo llevaría a producción

- Estado en Postgres y tokens en Redis, para poder correr varias instancias.
- Una cola persistente (Sidekiq, RabbitMQ o SQS) con reintentos: hoy, si el proceso se cae, los jobs pendientes se pierden.
- Header `Idempotency-Key` en `POST /products` para no duplicar productos cuando el cliente reintenta.
- Contraseñas hasheadas con bcrypt, HTTPS y rate limiting en `/auth`.
- Logs estructurados, métricas de la cola y alertas por jobs fallidos.
- CI con tests, RuboCop y validación del `openapi.yaml`.
