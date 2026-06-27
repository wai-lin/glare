# Getting Started

## Prerequisites

- [Node.js](https://nodejs.org/) v18+ (for esbuild and wrangler)
- A [Cloudflare account](https://dash.cloudflare.com/sign-up) (free tier works)
- Gleam installed

## Step 1: Create a new Gleam project

```bash
gleam new my-worker
cd my-worker
```

## Step 2: Add gflare

```bash
gleam add gflare
```

## Step 3: Initialize Cloudflare config

```bash
gleam run -m gflare -- init
```

This creates a `wrangler.toml` with the required fields:

```toml
name = "my-worker"
main = "./build/dist/bundle.js"
compatibility_date = "2025-01-15"
```

## Step 4: Write your handler

Replace `src/my_worker.gleam` with:

```gleam
import gflare/bindings.{type Env}
import gflare/worker.{type Context}
import gflare/request.{type HttpRequest}
import gflare/response
import gleam/javascript/promise

// This function is called for every HTTP request to your worker
pub fn fetch(request: HttpRequest, env: Env, ctx: Context) {
  // Create a response with status 200 (OK)
  response.new(200)
  // Set the response body text
  |> response.set_body("Hello from Gleam!")
  // Wrap in a Promise for Cloudflare
  |> promise.resolve
}
```

## Step 5: Run locally

```bash
gleam run -m gflare -- dev
```

Open http://localhost:8787 in your browser. You should see "Hello from Gleam!".

## Step 6: Deploy to Cloudflare

```bash
gleam run -m gflare -- deploy
```

Follow the prompts to authenticate with Cloudflare. Your worker will be deployed.

## What just happened?

1. `gleam build` compiled your Gleam to JavaScript (.mjs files)
2. gflare detected your `fetch` handler function
3. It generated `index.js` (Cloudflare Worker entrypoint) from your `wrangler.toml` bindings
4. esbuild bundled everything into `build/dist/bundle.js`
5. wrangler deployed to Cloudflare

## Next steps

- [Configuration](configuration.md) — customize your worker settings
- [KV](kv.md) — add key-value storage
- [D1](d1.md) — add a SQLite database
- [Turso](turso.md) — use Turso database over HTTP
- [Error Handling](error-handling.md) — learn proper error patterns
