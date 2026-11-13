# API de productos

API en Ruby y Rack para autenticarse, crear productos en segundo plano y consultarlos.

Autora: Yanina Emiliana Nuñez Gonzalez

## Contenido

| Archivo | Qué es |
| --- | --- |
| `fudo.md`, `tcp.md`, `http.md` | Notas sobre Fudo, TCP y HTTP |
| `config.ru` | Punto de entrada de Rack |
| `app/` | Código de la aplicación |
| `public/openapi.yaml` | Especificación OpenAPI 3.0 (servida en `/openapi.yaml`) |
| `public/AUTHORS` | Autora (servida en `/AUTHORS`) |

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

## Endpoints

| Método | Ruta | Auth | Respuesta |
| --- | --- | --- | --- |
| `POST` | `/auth` | No | `200` con token, `401` si las credenciales son inválidas |
| `POST` | `/products` | Sí | `202` con el job y header `Location` |
| `GET` | `/products` | Sí | `200` con los productos ya creados |
| `GET` | `/jobs/:id` | Sí | `200` con el estado del pedido (`pending`, `completed`, `failed`) |
| `GET` | `/openapi.yaml` | No | Especificación, `Cache-Control: no-store` |
| `GET` | `/AUTHORS` | No | Autora, `Cache-Control: public, max-age=86400` |

## Uso

```bash
# Obtener un token
TOKEN=$(curl -s -X POST localhost:9292/auth \
  -H 'Content-Type: application/json' \
  -d '{"username":"admin","password":"secret"}' | ruby -rjson -e 'puts JSON.parse(STDIN.read)["token"]')

# Solicitar un producto
curl -i -X POST localhost:9292/products \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"name":"Pizza muzzarella"}'

# Consultar los productos disponibles
curl -s localhost:9292/products -H "Authorization: Bearer $TOKEN"
# {"data":[]}

# Volver a consultar después de cinco segundos
sleep 5
curl -s localhost:9292/products -H "Authorization: Bearer $TOKEN"
# {"data":[{"id":1,"name":"Pizza muzzarella"}]}

# Solicitar gzip
curl -s -D - -o /dev/null -H 'Accept-Encoding: gzip' \
  localhost:9292/products -H "Authorization: Bearer $TOKEN"
# Content-Encoding: gzip
```

## Funcionamiento

Las rutas de productos y jobs requieren un token Bearer. Los archivos
`openapi.yaml` y `AUTHORS` son públicos. Rack se encarga de servirlos y de
comprimir las respuestas cuando el cliente acepta gzip.

Al crear un producto, la API devuelve `202` y la URL del job en `Location`.
El worker espera hasta la hora prevista, crea el producto y actualiza el estado
del job. Se puede consultar esa URL para saber si sigue pendiente, terminó o falló.

## Estado en memoria

Los productos, tokens y jobs se guardan en memoria y se pierden al reiniciar.
Puma usa un solo proceso para compartir ese estado entre los hilos.
Los stores usan `Mutex` para coordinar el acceso a los datos compartidos.
