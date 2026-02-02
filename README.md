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

## Tests

```bash
mix test
```
