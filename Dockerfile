FROM ruby:3.2.2-slim

RUN apt-get update -qq && \
    apt-get install -y build-essential libpq-dev git curl && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY Gemfile ./
RUN bundle install

COPY . .

RUN chmod +x bin/setup bin/docker-entrypoint bin/rails bin/rake .git-hooks/* 2>/dev/null || true

ENTRYPOINT ["bin/docker-entrypoint"]
EXPOSE 3000

CMD ["rails", "server", "-b", "0.0.0.0"]
