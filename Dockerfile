FROM ruby:3.3

WORKDIR /app

ENV RACK_ENV=production \
    PORT=9292

COPY Gemfile Gemfile.lock* ./
RUN bundle install

COPY . .

EXPOSE 9292

CMD ["bundle", "exec", "puma", "-C", "config/puma.rb", "-b", "tcp://0.0.0.0:9292"]
