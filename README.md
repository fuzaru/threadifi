# threadifi

Threadifi is a Phoenix LiveView application.

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

The app will be available at http://localhost:4000 and will auto-run migrations
and seeds on startup.

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
