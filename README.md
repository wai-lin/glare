# gflare

Zero-glue Gleam framework for Cloudflare Workers. Write Gleam, deploy to Cloudflare — no `index.js`, no `wrangler.toml` editing, no JavaScript.

[![Package Version](https://img.shields.io/hexpm/v/gflare)](https://hex.pm/packages/gflare)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/gflare)

## Quick Start

```bash
# Add to your project
gleam add gflare

# Initialize Cloudflare Workers in your project
gleam run -m gflare -- init

# Or run the wrangler dev with
gleam run -m gflare -- dev
```

### Minimal Example

```gleam
import gflare/bindings.{type Env}
import gflare/worker.{type Context}
import gflare/request.{type HttpRequest}
import gflare/response

pub fn fetch(request: HttpRequest, env: Env, ctx: Context) {
  response.new(200)
  |> response.set_body("Hello from Gleam!")
  |> promise.resolve
}
```

## CLI Commands

| Command | Description |
|---------|-------------|
| `gleam run -m gflare -- init` | Initialize Cloudflare Workers in current project |
| `gleam run -m gflare -- build` | Build for Cloudflare Workers |
| `gleam run -m gflare -- dev` | Build and start local dev server |
| `gleam run -m gflare -- deploy` | Build and deploy to Cloudflare |
| `gleam run -m gflare -- --help` | Show help |

## Configuration

Add a `[cloudflare]` section to your `gleam.toml`:

```toml
[cloudflare]
name = "my-worker"
compatibility_date = "2025-01-01"

[cloudflare.bindings]
kv = ["CACHE", "SESSIONS"]
d1 = ["DB"]
r2 = ["ASSETS"]
queues_producers = ["EVENTS"]
queues_consumers = ["events"]

[cloudflare.durable_objects]
classes = [
  { name = "Counter", module = "my_worker/durable_objects/counter" }
]

[cloudflare.vars]
ENVIRONMENT = "production"
```

> **Note:** Turso doesn't need a binding — just pass URL and token directly via `turso.connect()` or read from env vars with `bindings.var()`/`bindings.secret()`.

## Bindings

### Bindings Resolution

All bindings are resolved from the Cloudflare Worker `env` object:

```gleam
import gflare/bindings

pub fn fetch(request, env: Env, ctx: Context) {
  let assert Ok(cache) = bindings.kv(env, "CACHE")
  let assert Ok(db) = bindings.d1(env, "DB")
  let assert Ok(bucket) = bindings.r2(env, "ASSETS")
  let assert Ok(counter_ns) = bindings.durable_object(env, "COUNTER")
  let assert Ok(queue) = bindings.queue_producer(env, "EVENTS")
  let assert Ok(api_key) = bindings.secret(env, "API_KEY")
  let assert Ok(env) = bindings.var(env, "ENVIRONMENT")
  // ... use bindings
}
```

### KV (Key-Value Storage)

```gleam
import gflare/kv

pub fn fetch(request, env: Env, ctx: Context) {
  let assert Ok(cache) = bindings.kv(env, "CACHE")

  // Get a value
  use result <- promise.await(kv.get(cache, "greeting"))
  case result {
    Ok(value) -> response.new(200) |> response.set_body(value) |> promise.resolve
    Error(_) -> response.new(404) |> response.set_body("Not found") |> promise.resolve
  }
}

pub fn put_example(cache) {
  // Put with default options
  use _ <- promise.await(kv.put(cache, "key", "value", kv.put_options()))

  // Put with expiration (TTL)
  let opts = kv.put_options_with(expiration: None, expiration_ttl: Some(3600))
  use _ <- promise.await(kv.put(cache, "session:123", data, opts))

  // Get with cache TTL
  let opts = kv.get_options_with(type_: "json", cache_ttl: Some(60))
  use result <- promise.await(kv.get(cache, "key", opts))

  // List keys
  let opts = kv.list_options()
  use result <- promise.await(kv.list(cache, opts))
  case result {
    Ok(list_result) -> {
      // list_result.keys is a List(KvKey)
      // list_result.list_complete is Bool
      // list_result.cursor is Option(String) for pagination
    }
    Error(e) -> io.println_error(error.to_string(e))
  }

  // Delete a key
  use _ <- promise.await(kv.delete(cache, "old_key"))
}
```

### D1 (SQLite Database)

```gleam
import gflare/d1
import gleam/dynamic/decode

// Define a decoder for your query results
fn user_decoder() {
  use id <- decode.field("id", decode.int)
  use name <- decode.field("name", decode.string)
  use email <- decode.field("email", decode.string)
  decode.success(User(id:, name:, email:))
}

pub fn fetch_users(request, env: Env, ctx: Context) {
  let assert Ok(db) = bindings.d1(env, "DB")

  // Simple query
  let stmt = d1.prepare(db, "SELECT * FROM users LIMIT 10")
  use result <- promise.await(d1.all(stmt))
  case result {
    Ok(result) -> {
      // result.results is List(Dynamic) — decode each row
      let users = list.map(result.results, fn(row) {
        let assert Ok(user) = decode.run(row, user_decoder())
        user
      })
      response.new(200) |> response.json(json.array(users, user_to_json)) |> promise.resolve
    }
    Error(e) -> response.new(500) |> response.set_body(error.to_string(e)) |> promise.resolve
  }
}

pub fn insert_user(request, env: Env, ctx: Context) {
  let assert Ok(db) = bindings.d1(env, "DB")

  // Prepared statement with parameters
  let stmt = d1.prepare(db, "INSERT INTO users (name, email) VALUES (?, ?)")
  let stmt = d1.bind(stmt, [dynamic.from("Alice"), dynamic.from("alice@example.com")])
  use result <- promise.await(d1.run(stmt))
  case result {
    Ok(result) -> {
      // result.meta.last_row_id contains the inserted row ID
      response.new(201) |> response.set_body("Created") |> promise.resolve
    }
    Error(e) -> response.new(500) |> response.set_body(error.to_string(e)) |> promise.resolve
  }
}

pub fn get_user_by_id(request, env: Env, ctx: Context) {
  let assert Ok(db) = bindings.d1(env, "DB")

  // Get first row
  let stmt = d1.prepare(db, "SELECT * FROM users WHERE id = ?")
  let stmt = d1.bind(stmt, [dynamic.from(42)])
  use result <- promise.await(d1.first(stmt))
  case result {
    Ok(Some(row)) -> {
      let assert Ok(user) = decode.run(row, user_decoder())
      response.new(200) |> response.json(user_to_json(user)) |> promise.resolve
    }
    Ok(None) -> response.new(404) |> response.set_body("User not found") |> promise.resolve
    Error(e) -> response.new(500) |> response.set_body(error.to_string(e)) |> promise.resolve
  }
}

pub fn run_raw_sql(request, env: Env, ctx: Context) {
  let assert Ok(db) = bindings.d1(env, "DB")

  // Execute raw SQL
  use result <- promise.await(d1.exec(db, "CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY, name TEXT)"))
  response.new(200) |> response.set_body("OK") |> promise.resolve
}
```

### Turso (Database over HTTP)

Turso uses only `fetch` — no npm packages needed. Perfect for Cloudflare Workers.

```gleam
import gflare/turso

pub fn fetch(request, env: Env, ctx: Context) {
  // Read config from environment variables
  let assert Ok(url) = bindings.var(env, "TURSO_DATABASE_URL")
  let assert Ok(token) = bindings.secret(env, "TURSO_AUTH_TOKEN")
  let config = turso.connect(url, token)

  // Simple query
  use result <- promise.await(turso.execute(config, "SELECT * FROM users", []))
  case result {
    Ok(result) -> {
      // result.rows contains the rows
      // result.columns contains column names
      // result.rows_affected contains affected row count
      response.new(200) |> response.set_body("Found users") |> promise.resolve
    }
    Error(e) -> response.new(500) |> response.set_body(error.to_string(e)) |> promise.resolve
  }
}

pub fn query_with_params(request, env: Env, ctx: Context) {
  let assert Ok(url) = bindings.var(env, "TURSO_DATABASE_URL")
  let assert Ok(token) = bindings.secret(env, "TURSO_AUTH_TOKEN")
  let config = turso.connect(url, token)

  // Query with parameters
  use result <- promise.await(turso.execute(
    config,
    "SELECT * FROM users WHERE id = ?",
    [turso.int(42)],
  ))
  // Handle result...
}

pub fn batch_example(request, env: Env, ctx: Context) {
  let assert Ok(url) = bindings.var(env, "TURSO_DATABASE_URL")
  let assert Ok(token) = bindings.secret(env, "TURSO_AUTH_TOKEN")
  let config = turso.connect(url, token)

  // Batch execution
  use result <- promise.await(turso.batch(
    config,
    [
      #("INSERT INTO users (name) VALUES (?)", [turso.text("Alice")]),
      #("INSERT INTO users (name) VALUES (?)", [turso.text("Bob")]),
    ],
    turso.Write,
  ))
  // Handle result...
}

pub fn transaction_example(request, env: Env, ctx: Context) {
  let assert Ok(url) = bindings.var(env, "TURSO_DATABASE_URL")
  let assert Ok(token) = bindings.secret(env, "TURSO_AUTH_TOKEN")
  let config = turso.connect(url, token)

  // Transaction (rolls back on any error)
  use result <- promise.await(turso.transaction(config, [
    #("UPDATE accounts SET balance = balance - 100 WHERE id = 1", []),
    #("UPDATE accounts SET balance = balance + 100 WHERE id = 2", []),
  ]))
  // Handle result...
}
```

### Turso Platform API (Database Management)

Create, delete, and manage databases programmatically. Perfect for multi-tenant SaaS.

```gleam
import gflare/turso/cloud

pub fn main() {
  // Connect to Turso Platform API
  let api = cloud.connect("my-org", "platform-api-token")

  // Create a database for a new user
  use result <- promise.await(cloud.create_database(api, "user-abc123", "default"))
  case result {
    Ok(db) -> {
      // db.hostname, db.db_id, db.name
      io.println("Created database: " <> db.name)

      // Generate a scoped auth token
      use token_result <- promise.await(cloud.create_token(api, "user-abc123", "2w", "full-access"))
      case token_result {
        Ok(token) -> io.println("Token: " <> token.jwt)
        Error(e) -> io.println_error(error.to_string(e))
      }
    }
    Error(e) -> io.println_error(error.to_string(e))
  }

  // List all databases
  use result <- promise.await(cloud.list_databases(api))
  case result {
    Ok(databases) -> list.each(databases, fn(db) { io.println(db.name) })
    Error(e) -> io.println_error(error.to_string(e))
  }

  // Delete a database
  use _ <- promise.await(cloud.delete_database(api, "user-abc123"))

  // Group management
  use _ <- promise.await(cloud.create_group(api, "my-group"))
  use _ <- promise.await(cloud.delete_group(api, "my-group"))
  use result <- promise.await(cloud.list_groups(api))
  // ...
}
```

### R2 (Object Storage)

```gleam
import gflare/r2

pub fn get_file(request, env: Env, ctx: Context) {
  let assert Ok(bucket) = bindings.r2(env, "ASSETS")
  let key = request.path(request)

  use result <- promise.await(r2.get(bucket, key))
  case result {
    Ok(body) -> {
      // Read as text
      use text <- promise.await(r2.read_text(body))
      case text {
        Ok(content) -> response.new(200) |> response.set_body(content) |> promise.resolve
        Error(e) -> response.new(500) |> response.set_body(error.to_string(e)) |> promise.resolve
      }
    }
    Error(_) -> response.new(404) |> response.set_body("File not found") |> promise.resolve
  }
}

pub fn upload_file(request, env: Env, ctx: Context) {
  let assert Ok(bucket) = bindings.r2(env, "ASSETS")
  use body <- promise.await(request.array_buffer(request))

  case body {
    Ok(bytes) -> {
      let opts = r2.put_options_with(
        http_metadata: Some(r2.HttpMetadata(
          content_type: Some("text/plain"),
          content_disposition: None,
          content_encoding: None,
          cache_control: None,
          cache_expiry: None,
        )),
        custom_metadata: None,
      )
      use result <- promise.await(r2.put(bucket, "uploads/file.txt", bytes, opts))
      case result {
        Ok(obj) -> response.new(200) |> response.set_body("Uploaded: " <> obj.key) |> promise.resolve
        Error(e) -> response.new(500) |> response.set_body(error.to_string(e)) |> promise.resolve
      }
    }
    Error(e) -> response.new(400) |> response.set_body(e) |> promise.resolve
  }
}

pub fn list_files(request, env: Env, ctx: Context) {
  let assert Ok(bucket) = bindings.r2(env, "ASSETS")
  let opts = r2.list_options_with(
    prefix: Some("uploads/"),
    cursor: None,
    delimiter: None,
    limit: Some(100),
    include: None,
  )
  use result <- promise.await(r2.list(bucket, opts))
  case result {
    Ok(list_result) -> {
      // list_result.objects is List(ListObject)
      // list_result.truncated is Bool
      // list_result.delimited_prefixes is List(String)
      response.new(200) |> response.set_body("Found files") |> promise.resolve
    }
    Error(e) -> response.new(500) |> response.set_body(error.to_string(e)) |> promise.resolve
  }
}

pub fn delete_file(request, env: Env, ctx: Context) {
  let assert Ok(bucket) = bindings.r2(env, "ASSETS")
  use _ <- promise.await(r2.delete(bucket, "old-file.txt"))
  response.new(204) |> promise.resolve
}

pub fn file_metadata(request, env: Env, ctx: Context) {
  let assert Ok(bucket) = bindings.r2(env, "ASSETS")
  use result <- promise.await(r2.head(bucket, "file.txt"))
  case result {
    Ok(meta) -> response.new(200) |> response.set_body(meta.etag) |> promise.resolve
    Error(e) -> response.new(404) |> response.set_body(error.to_string(e)) |> promise.resolve
  }
}
```

### Queues (Message Queue)

```gleam
import gflare/queue
import gleam/json

// Producer: send messages
pub fn enqueue_job(request, env: Env, ctx: Context) {
  let assert Ok(q) = bindings.queue_producer(env, "EVENTS")
  let message = json.object([
    #("type", json.string("email")),
    #("to", json.string("user@example.com")),
    #("subject", json.string("Welcome!")),
  ])
  use _ <- promise.await(queue.send(q, message))
  response.new(200) |> response.set_body("Job queued") |> promise.resolve
}

// Producer: send batch
pub fn enqueue_batch(request, env: Env, ctx: Context) {
  let assert Ok(q) = bindings.queue_producer(env, "EVENTS")
  let messages = [
    json.object([#("type", json.string("email")), #("to", json.string("a@test.com"))]),
    json.object([#("type", json.string("email")), #("to", json.string("b@test.com"))]),
  ]
  use _ <- promise.await(queue.send_batch(q, messages))
  response.new(200) |> response.set_body("Batch queued") |> promise.resolve
}

// Consumer: process messages
pub fn queue(batch, env: Env, ctx: Context) {
  list.each(batch.messages, fn(msg) {
    let body = queue.message_body(msg)
    let id = queue.message_id(msg)
    let attempts = queue.message_attempts(msg)
    // Process the message...
    io.println("Processing message " <> id <> " (attempt " <> int.to_string(attempts) <> ")")
    // Acknowledge on success
    let assert Ok(_) = queue.ack(msg)
    // Or retry on failure
    // let assert Ok(_) = queue.retry(msg)
  })
  promise.resolve(Nil)
}
```

### Durable Objects

```gleam
import gflare/durable_object

pub fn fetch(request, env: Env, ctx: Context) {
  let assert Ok(ns) = bindings.durable_object(env, "COUNTER")

  // Get a deterministic ID from a name
  let id = durable_object.id_from_name(ns, "user:42")

  // Get a stub (proxy to the DO instance)
  let stub = durable_object.get_stub(ns, id)

  // Call the DO
  use result <- promise.await(durable_object.get(stub))
  case result {
    Ok(data) -> response.new(200) |> response.json(data) |> promise.resolve
    Error(e) -> response.new(500) |> response.set_body(error.to_string(e)) |> promise.resolve
  }
}

pub fn increment_counter(request, env: Env, ctx: Context) {
  let assert Ok(ns) = bindings.durable_object(env, "COUNTER")
  let id = durable_object.id_from_name(ns, "global")
  let stub = durable_object.get_stub(ns, id)
  use _ <- promise.await(durable_object.set(stub, "count", json.int(1)))
  response.new(200) |> response.set_body("Incremented") |> promise.resolve
}

pub fn schedule_alarm(request, env: Env, ctx: Context) {
  let assert Ok(ns) = bindings.durable_object(env, "COUNTER")
  let id = durable_object.id_from_name(ns, "scheduler")
  let stub = durable_object.get_stub(ns, id)
  // Set alarm 60 seconds from now
  let timestamp = 1_700_000_000_000 + 60_000
  use _ <- promise.await(durable_object.set_alarm(stub, timestamp))
  response.new(200) |> response.set_body("Alarm scheduled") |> promise.resolve
}
```

### Worker Context

```gleam
import gflare/worker

pub fn fetch(request, env: Env, ctx: Context) {
  // Extend worker lifetime for background work
  use _ <- promise.await(background_task(env))
  worker.wait_until(ctx, background_promise)

  // Or pass through to origin on exceptions
  worker.pass_through_on_exception(ctx)

  response.new(200) |> response.set_body("OK") |> promise.resolve
}
```

### Request Helpers

```gleam
import gflare/request

pub fn handler(request, env: Env, ctx: Context) {
  let url = request.url(request)
  let method = request.method(request)
  let headers = request.headers(request)
  // headers is List(#(String, String))

  // Read body as text
  use body <- promise.await(request.text(request))
  case body {
    Ok(text) -> response.new(200) |> response.set_body(text) |> promise.resolve
    Error(e) -> response.new(400) |> response.set_body(e) |> promise.resolve
  }

  // Or read as JSON
  use json_body <- promise.await(request.json(request))
  case json_body {
    Ok(data) -> {
      // data is Dynamic — decode it
      let assert Ok(name) = decode.run(data, decode.field("name", decode.string, decode.success))
      response.new(200) |> response.set_body("Hello " <> name) |> promise.resolve
    }
    Error(e) -> response.new(400) |> response.set_body(e) |> promise.resolve
  }

  // Or read raw bytes
  use bytes <- promise.await(request.array_buffer(request))
  // bytes is BitArray
}
```

### Response Helpers

```gleam
import gflare/response
import gleam/json

// Text response
response.new(200)
|> response.set_body("Hello, World!")
|> response.set_header("X-Custom", "value")

// JSON response
response.new(200)
|> response.json(json.object([#("status", json.string("ok"))]))

// Binary response
response.new(200)
|> response.bytes(<<30, 56, 10>>)

// Empty response
response.new(204)

// Redirect
response.redirect("https://example.com", 302)

// Pipe-friendly: all functions return Response
response.new(200)
|> response.set_header("Cache-Control", "no-cache")
|> response.set_body("No cache here!")
```

### JSON Utilities

```gleam
import gflare/json_util
import gleam/json

// Create JSON objects (filters out null values)
let data = json_util.sparse([
  #("name", json.string("Alice")),
  #("age", json.null()),  // This will be omitted
  #("active", json.bool(True)),
])

// Option to JSON
let value = json_util.option_to_json(Some(42), json.int)
// value == json.int(42)

let nothing = json_util.option_to_json(None, json.int)
// nothing == json.null()

// Parse JSON string
case json_util.parse("{\"key\": \"value\"}") {
  Ok(dynamic) -> // use dynamic
  Error(msg) -> io.println_error(msg)
}

// Decoder helpers
let decoder = {
  use name <- decode.field("name", decode.string)
  use age <- decode.field("age", decode.int)
  decode.success(Person(name:, age:))
}
```

### Error Handling

All binding operations return `Result(T, gflare/error.Error)`:

```gleam
import gflare/error

case result {
  Ok(value) -> // use value
  Error(err) -> io.println_error(error.to_string(err))
  // Error variants:
  // KvError(message)
  // D1Error(message)
  // R2Error(message)
  // DurableObjectError(message)
  // QueueError(message)
  // BindingNotFound(name)
  // EncodingError(message)
  // DecodingError(message)
}
```

## Full Example

A complete worker with KV caching, D1 database, and Turso:

```gleam
import gflare/bindings.{type Env}
import gflare/worker.{type Context}
import gflare/request.{type HttpRequest}
import gflare/response
import gflare/kv
import gflare/d1
import gflare/turso
import gflare/json_util
import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option.{None, Some}

pub type User {
  User(id: Int, name: String, email: String)
}

fn user_decoder() {
  use id <- decode.field("id", decode.int)
  use name <- decode.field("name", decode.string)
  use email <- decode.field("email", decode.string)
  decode.success(User(id:, name:, email:))
}

fn user_to_json(user: User) -> json.Json {
  json.object([
    #("id", json.int(user.id)),
    #("name", json.string(user.name)),
    #("email", json.string(user.email)),
  ])
}

pub fn fetch(request: HttpRequest, env: Env, ctx: Context) {
  let assert Ok(cache) = bindings.kv(env, "CACHE")

  // Try KV cache first
  use cached <- promise.await(kv.get(cache, "users"))
  case cached {
    Ok(json_str) -> {
      // Cache hit — return cached data
      let assert Ok(data) = json_util.parse(json_str)
      response.new(200) |> response.json(data) |> promise.resolve
    }
    Error(_) -> {
      // Cache miss — query Turso (better for transactions than D1)
      let assert Ok(url) = bindings.var(env, "TURSO_DATABASE_URL")
      let assert Ok(token) = bindings.secret(env, "TURSO_AUTH_TOKEN")
      let config = turso.connect(url, token)

      use result <- promise.await(turso.execute(config, "SELECT * FROM users", []))
      case result {
        Ok(result) -> {
          let users =
            list.map(result.rows, fn(row) {
              let assert Ok(user) = decode.run(user_decoder(), decode.dynamic)
              user
            })
          let json_data = json.array(users, user_to_json)
          // Cache for 5 minutes
          let cache_opts = kv.put_options_with(expiration: None, expiration_ttl: Some(300))
          use _ <- promise.await(kv.put(cache, "users", json_util.sparse([#("data", json_data)]), cache_opts))
          response.new(200) |> response.json(json_data) |> promise.resolve
        }
        Error(e) -> response.new(500) |> response.set_body(error.to_string(e)) |> promise.resolve
      }
    }
  }
}
```

## How It Works

```
┌─────────────────────────────────────────────────┐
│  Your Gleam code (handlers + binding calls)     │
├─────────────────────────────────────────────────┤
│  gflare library (types, FFI, wrappers)           │
├─────────────────────────────────────────────────┤
│  gleam build                               │
│  → outputs .mjs files in build/dev/javascript/  │
├─────────────────────────────────────────────────┤
│  gflare CLI (detects handlers, generates glue)   │
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
