# Configuration

gflare uses `wrangler.toml` as the source of truth for all Cloudflare Worker configuration. Your `gleam.toml` is only used for Gleam package settings.

## Quick Start

```bash
gleam run -m gflare -- init
```

This creates a minimal `wrangler.toml` if it doesn't exist, or adds missing fields if it does.

## wrangler.toml

gflare reads your standard `wrangler.toml` for all Cloudflare configuration:

```toml
name = "my-worker"
main = "./build/dist/bundle.js"
compatibility_date = "2025-01-15"

[[d1_databases]]
binding = "DB"
database_name = "my-db"
database_id = "your-uuid-here"
migrations_dir = "./db/migrations"

[[kv_namespaces]]
binding = "CACHE"
id = "your-kv-id"

[[r2_buckets]]
binding = "ASSETS"
bucket_name = "my-assets"

[vars]
ENVIRONMENT = "production"

[durable_objects]
bindings = [
  { name = "Counter", class_name = "Counter" },
]
```

This is standard wrangler.toml format — no gflare-specific sections needed.

## Bindings

### D1 Databases

```toml
[[d1_databases]]
binding = "DB"                        # Binding name (env.DB in your worker)
database_name = "my-database"         # Database name in Cloudflare
database_id = "your-uuid-here"       # Database ID from Cloudflare dashboard
migrations_dir = "./db/migrations"   # Path to migration SQL files
```

All fields except `binding` are optional.

Multiple D1 databases:

```toml
[[d1_databases]]
binding = "DB"
database_name = "main-db"
database_id = "abc-123"

[[d1_databases]]
binding = "DB_REPLICA"
database_name = "replica-db"
database_id = "xyz-789"
```

### KV Namespaces

```toml
[[kv_namespaces]]
binding = "CACHE"
id = "your-kv-namespace-id"
```

### R2 Buckets

```toml
[[r2_buckets]]
binding = "ASSETS"
bucket_name = "my-assets"
```

### Queues

```toml
[[queues.producers]]
binding = "EVENTS"
queue_name = "events"

[[queues.consumers]]
queue = "events"
```

## Environment Variables

```toml
[vars]
ENVIRONMENT = "production"
DEBUG = "true"
```

For secrets (encrypted at rest), use `wrangler secret put API_KEY` after deployment.

## Durable Objects

```toml
[durable_objects]
bindings = [
  { name = "Counter", class_name = "Counter" },
]
```

## How It Works

1. `gflare init` — creates/updates `wrangler.toml` with `name`, `main`, `compatibility_date`
2. `gflare build` — reads `wrangler.toml` for bindings, generates entrypoint and DO wrappers
3. esbuild bundles everything into `build/dist/bundle.js`
4. wrangler deploys using your `wrangler.toml`

## Related

- [Bindings](bindings.md) — how to use bindings in your code
- [Durable Objects](durable-objects.md) — working with Durable Objects
