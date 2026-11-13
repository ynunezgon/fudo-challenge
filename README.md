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

## Estado en memoria

Los productos, tokens y jobs se guardan en memoria y se pierden al reiniciar.
Puma usa un solo proceso para compartir ese estado entre los hilos.
Los stores usan `Mutex` para coordinar el acceso a los datos compartidos.
