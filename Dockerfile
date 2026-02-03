ARG ELIXIR_VERSION=1.18.3
ARG OTP_VERSION=27
ARG DEBIAN_VERSION=bookworm

FROM elixir:${ELIXIR_VERSION}-otp-${OTP_VERSION} AS build

ENV MIX_ENV=prod
WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
  build-essential \
  git \
  npm \
  && rm -rf /var/lib/apt/lists/*

RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs mix.lock ./
COPY config config
COPY assets/package.json assets/package-lock.json* assets/
RUN mix deps.get --only ${MIX_ENV}

COPY priv priv
COPY lib lib
COPY assets assets

RUN npm install --prefix assets
RUN mix assets.deploy
RUN mix release

FROM debian:${DEBIAN_VERSION}-slim AS app
RUN apt-get update && apt-get install -y --no-install-recommends \
  openssl \
  libstdc++6 \
  && rm -rf /var/lib/apt/lists/*

ENV MIX_ENV=prod
WORKDIR /app

COPY --from=build /app/_build/prod/rel/threadifi ./

ENV PHX_SERVER=true
ENV PORT=4000

EXPOSE 4000

CMD ["bin/threadifi", "start"]
