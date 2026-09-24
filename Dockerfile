# syntax=docker/dockerfile:1

# Keep in sync with .ruby-version
ARG RUBY_VERSION=3.4.11

# ---------------------------------------------------------------------------
# base: runtime libraries shared by every stage
# ---------------------------------------------------------------------------
FROM ruby:${RUBY_VERSION}-slim-trixie AS base

WORKDIR /app

RUN apt-get update -qq \
 && apt-get install -y --no-install-recommends \
      default-mysql-client libmariadb3 libyaml-0-2 tzdata curl \
 && rm -rf /var/lib/apt/lists/*

ENV BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_JOBS=4 \
    BUNDLE_RETRY=3 \
    LANG=C.UTF-8

# ---------------------------------------------------------------------------
# development: toolchain for native gems; source is bind-mounted by compose
# ---------------------------------------------------------------------------
FROM base AS development

RUN apt-get update -qq \
 && apt-get install -y --no-install-recommends \
      build-essential default-libmysqlclient-dev libyaml-dev pkg-config git \
 && rm -rf /var/lib/apt/lists/*

ENV RAILS_ENV=development \
    DOCKER=true

# Dependency manifests first so the gem layer is cached until they change.
COPY .ruby-version Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

ENTRYPOINT ["bin/docker-entrypoint"]
EXPOSE 3000
CMD ["bin/rails", "server", "-b", "0.0.0.0", "-p", "3000"]
