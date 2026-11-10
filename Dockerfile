# Imagen completa (no slim): Puma compila una extensión nativa y necesita compilador.
FROM ruby:3.3

WORKDIR /app

ENV RACK_ENV=production \
    BUNDLE_WITHOUT=test \
    PORT=9292

# Primero sólo el Gemfile para aprovechar la caché de capas de Docker.
COPY Gemfile Gemfile.lock* ./
RUN bundle install

COPY . .

EXPOSE 9292

# Bind a 0.0.0.0 para que el puerto sea accesible desde fuera del contenedor.
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb", "-b", "tcp://0.0.0.0:9292"]
