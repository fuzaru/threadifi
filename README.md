# threadifi

Threadifi is a Phoenix LiveView application.

## Quickstart (after cloning)

### Option 1: Local Postgres + local run

0. Create your local env file:

```bash
cp .env.example .env
set -a
source .env
set +a
```

1. Start Postgres and make sure this user/password works:

```bash
threadifi / threadifi_dev
```

If you need to create it:

```bash
sudo -u postgres psql -c "CREATE ROLE threadifi WITH LOGIN PASSWORD 'threadifi_dev';"
sudo -u postgres psql -c "ALTER ROLE threadifi CREATEDB;"
```

2. Install project dependencies and assets:

```bash
mix deps.get
cd assets && npm install && cd ..
mix assets.setup
```

3. Export DB env vars and prepare databases:

```bash
export DB_USER=threadifi
export DB_PASSWORD=threadifi_dev
export DB_HOST=localhost
mix ecto.setup
MIX_ENV=test mix ecto.create
MIX_ENV=test mix ecto.migrate
```

4. Run tests:

```bash
mix test
```

5. Run the app:

```bash
mix phx.server
```

Then visit http://localhost:4000.

### Option 2: Docker (fastest zero-local-setup path)

```bash
docker compose up --build
```

The app will be available at http://localhost:4000 and will auto-run migrations and seeds.

## CI

GitHub Actions workflow: `.github/workflows/ci.yml`

It runs:

```bash
mix deps.get
npm ci --prefix assets
mix compile --warnings-as-errors
mix format --check-formatted
mix credo --all
mix ecto.create
mix ecto.migrate
mix test
```

with a Postgres 16 service (`threadifi` / `threadifi_dev`).

## Deployment Runbook (Docker release image)

1. Build image:

```bash
docker build -t threadifi:latest .
```

2. Set runtime env vars:

```bash
export DATABASE_URL='ecto://threadifi:threadifi_dev@<db-host>/threadifi_dev'
export SECRET_KEY_BASE="$(mix phx.gen.secret)"
export PHX_HOST='your-domain-or-ip'
export PORT=4000
```

3. Start the release:

```bash
docker run --rm -p 4000:4000 \
  -e DATABASE_URL \
  -e SECRET_KEY_BASE \
  -e PHX_HOST \
  -e PORT \
  threadifi:latest
```

4. Smoke test:

```bash
curl -I http://localhost:4000
```

5. Rollback:

```bash
docker run --rm -p 4000:4000 \
  -e DATABASE_URL \
  -e SECRET_KEY_BASE \
  -e PHX_HOST \
  -e PORT \
  threadifi:<previous-tag>
```

## Setup

```bash
mix deps.get
mix ecto.create
mix ecto.migrate
mix assets.setup
```

## Run the app

```bash
mix phx.server
```

Then visit http://localhost:4000.

Auth routes are available at `/users/register`, `/users/log-in`, and `/users/settings`.

## Seeds (demo data)

```bash
mix run priv/repo/seeds.exs
```

This will create the **Threadifi Demo** workspace with channels and sample messages
when at least one user exists.

## Docker (dev)

```bash
docker compose up --build
```

The app will be available at http://localhost:4000 and will auto-run migrations and seeds on startup.

## Docker (release image)

```bash
docker build -t threadifi .
docker run --rm -p 4000:4000 \
  -e DATABASE_URL=ecto://threadifi:threadifi_dev@localhost/threadifi_dev \
  -e SECRET_KEY_BASE=$(mix phx.gen.secret) \
  threadifi
```

## Screenshots

- `docs/screenshots/workspaces.png`
- `docs/screenshots/channel.png`
- `docs/screenshots/thread.png`
- `docs/screenshots/snippets.png`

## Tests

```bash
mix test
```
