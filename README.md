# gflare

<p align="center">
  <img src="images/gflare.svg" alt="gflare logo" width="200">
</p>

Zero-glue Gleam framework for Cloudflare Workers. Write Gleam, deploy to Cloudflare — no `index.js`, no JavaScript.

[![Package Version](https://img.shields.io/hexpm/v/gflare)](https://hex.pm/packages/gflare)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/gflare)

## Quick Example

```gleam
import gflare/bindings.{type Env}
import gflare/worker.{type Context}
import gflare/request.{type HttpRequest}
import gflare/response
import gleam/javascript/promise

// This function handles every HTTP request to your worker
pub fn fetch(request: HttpRequest, env: Env, ctx: Context) {
  response.new(200)
  |> response.set_body("Hello from Gleam!")
  |> promise.resolve
}
```

## Features

- Pure Gleam bindings for Cloudflare Workers APIs
- KV, D1, R2, Queues, Durable Objects support
- Turso database over HTTP (no npm packages)
- SQL code generation (like squirrel for SQLite)
- Database migrations for D1 and Turso
- Typed error handling
- esbuild bundling, wrangler integration

## Quick Start

```bash
gleam new my-worker
cd my-worker
gleam add gflare
gleam run -m gflare -- init
```

Write your handler, then:

```bash
gleam run -m gflare -- dev    # Run locally
gleam run -m gflare -- deploy # Deploy to Cloudflare
```

## Documentation

| Guide | Description |
|-------|-------------|
| [Getting Started](docs/getting-started.md) | Install, setup, and first worker |
| [Configuration](docs/configuration.md) | gleam.toml reference |
| [Bindings](docs/bindings.md) | How bindings work |
| [KV](docs/kv.md) | Key-value storage |
| [D1](docs/d1.md) | SQLite database |
| [Turso](docs/turso.md) | Turso database over HTTP |
| [R2](docs/r2.md) | Object storage |
| [Queues](docs/queues.md) | Message queues |
| [Durable Objects](docs/durable-objects.md) | Stateful objects |
| [Code Generation](docs/code-generation.md) | SQL to Gleam code |
| [Migrations](docs/migrations.md) | Database migrations |
| [Error Handling](docs/error-handling.md) | Error patterns |
| [Router](docs/router.md) | Routing and middleware |
| [CORS](docs/cors.md) | Cross-Origin Resource Sharing |
| [Rate Limiting](docs/rate-limiting.md) | Request rate limiting |
| [Validation](docs/validation.md) | Request validation |
| [Logging](docs/logging.md) | Structured logging |
| [Troubleshooting](docs/troubleshooting.md) | Common issues |

## CLI Commands

| Command | Description |
|---------|-------------|
| `gleam run -m gflare -- init` | Initialize Cloudflare Workers |
| `gleam run -m gflare -- build` | Build for Cloudflare Workers |
| `gleam run -m gflare -- dev` | Build and start local dev server |
| `gleam run -m gflare -- deploy` | Build and deploy to Cloudflare |
| `gleam run -m gflare -- db generate` | Generate Gleam code from SQL |
| `gleam run -m gflare -- db generate --backend turso` | Generate for Turso |
| `gleam run -m gflare -- db migrate create <name>` | Create a migration |
| `gleam run -m gflare -- db migrate list` | List migration files |
| `gleam run -m gflare -- db migrate run` | Apply pending migrations |
| `gleam run -m gflare -- db migrate run --turso` | Apply migrations to Turso |

## How It Works

```
┌─────────────────────────────────────────────────┐
│  Your Gleam code (handlers + binding calls)     │
├─────────────────────────────────────────────────┤
│  gflare library (types, FFI, wrappers)          │
├─────────────────────────────────────────────────┤
│  gleam build                                    │
│  → outputs .mjs files in build/dev/javascript/  │
├─────────────────────────────────────────────────┤
│  gflare CLI (detects handlers, generates glue)  │
│  → generates index.js + wrangler.toml           │
├─────────────────────────────────────────────────┤
│  esbuild (bundles into single file)             │
├─────────────────────────────────────────────────┤
│  wrangler dev / wrangler deploy                 │
└─────────────────────────────────────────────────┘
```

1. `gleam build` compiles your Gleam to `.mjs` files
2. The CLI scans the compiled output for exported handlers (`fetch`, `queue`, etc.)
3. It generates `index.js` (Cloudflare Worker entrypoint) and `wrangler.toml`
4. `esbuild` bundles everything into a single file
5. `wrangler` runs locally or deploys to Cloudflare

## License

MIT — see [LICENSE](LICENSE) for details.
