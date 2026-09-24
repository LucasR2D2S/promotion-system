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

# ---------------------------------------------------------------------------
# build: compiles gems and assets for production (toolchain stays in this stage)
# ---------------------------------------------------------------------------
FROM base AS build

RUN apt-get update -qq \
 && apt-get install -y --no-install-recommends \
      build-essential default-libmysqlclient-dev libyaml-dev pkg-config git \
 && rm -rf /var/lib/apt/lists/*

ENV RAILS_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_WITHOUT="development:test"

COPY .ruby-version Gemfile Gemfile.lock ./
RUN bundle install \
 && rm -rf "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git \
 && bundle exec bootsnap precompile --gemfile

COPY . .

# Precompile bootsnap caches and assets. Assets need a secret key base but no real
# secrets: SECRET_KEY_BASE_DUMMY makes Rails generate a throwaway one.
RUN bundle exec bootsnap precompile app/ lib/ \
 && SECRET_KEY_BASE_DUMMY=1 bin/rails assets:precompile \
 && rm -rf node_modules tmp/cache spec

# ---------------------------------------------------------------------------
# production: slim runtime image, no compilers, non-root user
# ---------------------------------------------------------------------------
FROM base AS production

ENV RAILS_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_WITHOUT="development:test"

COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /app /app

RUN groupadd --system --gid 1000 rails \
 && useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash \
 && mkdir -p log tmp/pids \
 && chown -R rails:rails log tmp db
USER 1000:1000

ENTRYPOINT ["bin/docker-entrypoint"]
EXPOSE 3000
HEALTHCHECK --interval=10s --timeout=3s --start-period=30s --retries=3 \
  CMD curl -fsS http://localhost:3000/up || exit 1
CMD ["bin/rails", "server", "-b", "0.0.0.0", "-p", "3000"]
