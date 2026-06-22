# gflare

Zero-glue Gleam framework for Cloudflare Workers. Write Gleam, deploy to Cloudflare — no `index.js`, no `wrangler.toml` editing, no JavaScript.

[![Package Version](https://img.shields.io/hexpm/v/gflare)](https://hex.pm/packages/gflare)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/gflare)

## Quick Start

```bash
gleam add gflare
gleam run -m gflare -- init
```

Create your handler:

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

Run locally:

```bash
gleam run -m gflare -- dev
```

## Features

- Pure Gleam bindings for Cloudflare Workers APIs
- KV, D1, R2, Queues, Durable Objects support
- Turso database over HTTP (no npm packages)
- SQL code generation (like squirrel for SQLite)
- Database migrations for D1 and Turso
- Typed error handling
- esbuild bundling, wrangler integration

## CLI Commands

| Command | Description |
|---------|-------------|
| `gleam run -m gflare -- init` | Initialize Cloudflare Workers in current project |
| `gleam run -m gflare -- build` | Build for Cloudflare Workers |
| `gleam run -m gflare -- dev` | Build and start local dev server |
| `gleam run -m gflare -- deploy` | Build and deploy to Cloudflare |
| `gleam run -m gflare -- db generate` | Generate Gleam code from `*.sql` files |
| `gleam run -m gflare -- db generate --backend turso` | Generate for Turso backend |
| `gleam run -m gflare -- db migrate create <name>` | Create a new migration |
| `gleam run -m gflare -- db migrate list` | List migration files |
| `gleam run -m gflare -- db migrate run` | Apply pending migrations |

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

## Bindings

All bindings are resolved from the Cloudflare Worker `env` object:

```gleam
import gflare/bindings

pub fn fetch(request, env: Env, ctx: Context) {
  let assert Ok(cache) = bindings.kv(env, "CACHE")
  let assert Ok(db) = bindings.d1(env, "DB")
  let assert Ok(bucket) = bindings.r2(env, "ASSETS")
  let assert Ok(ns) = bindings.durable_object(env, "COUNTER")
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
  use result <- promise.await(kv.get(cache, "greeting", kv.get_options()))
  case result {
    Ok(value) -> response.new(200) |> response.set_body(value) |> promise.resolve
    Error(_) -> response.new(404) |> response.set_body("Not found") |> promise.resolve
  }
}
```

```gleam
// Put with default options
use _ <- promise.await(kv.put(cache, "key", "value", kv.put_options()))

// Put with TTL (expires in 1 hour)
let opts = kv.put_options_with(expiration: None, expiration_ttl: Some(3600))
use _ <- promise.await(kv.put(cache, "session:123", data, opts))

// Get with cache TTL
let opts = kv.get_options_with(type_: "json", cache_ttl: Some(60))
use result <- promise.await(kv.get(cache, "key", opts))

// List keys
use result <- promise.await(kv.list(cache, kv.list_options()))
case result {
  Ok(list_result) -> {
    // list_result.keys: List(KvKey)
    // list_result.list_complete: Bool
    // list_result.cursor: Option(String) for pagination
  }
  Error(e) -> io.println_error(error.to_string(e))
}

// Delete a key
use _ <- promise.await(kv.delete(cache, "old_key"))
```

### D1 (SQLite Database)

```gleam
import gflare/d1
import gleam/dynamic/decode

pub type User {
  User(id: Int, name: String, email: String)
}

// D1 returns rows as objects with column names as keys
fn user_decoder() {
  use id <- decode.field("id", decode.int)
  use name <- decode.field("name", decode.string)
  use email <- decode.field("email", decode.string)
  decode.success(User(id:, name:, email:))
}
```

```gleam
// Simple query
let stmt = d1.prepare(db, "SELECT * FROM users LIMIT 10")
use result <- promise.await(d1.all(stmt))
case result {
  Ok(result) -> {
    let users = list.map(result.results, fn(row) {
      let assert Ok(user) = decode.run(row, user_decoder())
      user
    })
    // users is List(User)
  }
  Error(e) -> io.println_error(error.to_string(e))
}
```

```gleam
// Prepared statement with typed parameters
let stmt = d1.prepare(db, "INSERT INTO users (name, email) VALUES (?, ?)")
let stmt = d1.bind(stmt, [d1.text("Alice"), d1.text("alice@example.com")])
use result <- promise.await(d1.run(stmt))
case result {
  Ok(result) -> {
    // result.meta.last_row_id contains the inserted row ID
  }
  Error(e) -> io.println_error(error.to_string(e))
}
```

```gleam
// Get first row
let stmt = d1.prepare(db, "SELECT * FROM users WHERE id = ?")
let stmt = d1.bind(stmt, [d1.int(42)])
use result <- promise.await(d1.first(stmt))
case result {
  Ok(Some(row)) -> decode.run(row, user_decoder())
  Ok(None) -> Error("User not found")
  Error(e) -> Error(error.to_string(e))
}
```

```gleam
// Execute raw SQL (no return values)
use result <- promise.await(d1.exec(db, "CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY, name TEXT)"))
```

**D1 Helper Functions:**

```gleam
d1.int(42)           // Int → Dynamic
d1.float(3.14)       // Float → Dynamic
d1.text("hello")     // String → Dynamic
d1.bool(True)        // Bool → Dynamic (0/1)
d1.blob(<<1, 2, 3>>) // BitArray → Dynamic
d1.null_value()      // null → Dynamic
```

### Turso (Database over HTTP)

Turso uses only `gleam_fetch` — no npm packages needed. Perfect for Cloudflare Workers.

```gleam
import gflare/turso

pub fn fetch(request, env: Env, ctx: Context) {
  let assert Ok(url) = bindings.var(env, "TURSO_DATABASE_URL")
  let assert Ok(token) = bindings.secret(env, "TURSO_AUTH_TOKEN")
  let config = turso.connect(url, token)

  use result <- promise.await(turso.execute(config, "SELECT * FROM users", []))
  case result {
    Ok(result) -> {
      // result.rows: List(Row)
      // result.columns: List(String)
      // result.rows_affected: Int
      response.new(200) |> response.set_body("Found users") |> promise.resolve
    }
    Error(e) -> response.new(500) |> response.set_body(error.to_string(e)) |> promise.resolve
  }
}
```

```gleam
// Query with parameters
use result <- promise.await(turso.execute(
  config,
  "SELECT * FROM users WHERE id = ?",
  [turso.int(42)],
))

// Batch execution
use result <- promise.await(turso.batch(
  config,
  [
    #("INSERT INTO users (name) VALUES (?)", [turso.text("Alice")]),
    #("INSERT INTO users (name) VALUES (?)", [turso.text("Bob")]),
  ],
  Nil,
))

// Transaction (rolls back on any error)
use result <- promise.await(turso.transaction(config, [
  #("UPDATE accounts SET balance = balance - 100 WHERE id = 1", []),
  #("UPDATE accounts SET balance = balance + 100 WHERE id = 2", []),
]))
```

**Turso Value Constructors:**

```gleam
turso.int(42)           // Integer
turso.float(3.14)       // Float
turso.text("hello")     // Text
turso.blob(<<1, 2, 3>>) // Blob
turso.null_value()      // Null
```

### Turso Platform API

Create, delete, and manage databases programmatically. Perfect for multi-tenant SaaS.

```gleam
import gflare/turso/cloud

pub fn main() {
  let api = cloud.connect("my-org", "platform-api-token")

  // Create a database for a new tenant
  use result <- promise.await(cloud.create_database(api, "tenant-abc", "default"))
  case result {
    Ok(db) -> {
      io.println("Created: " <> db.hostname)

      // Generate a scoped auth token
      use token_result <- promise.await(cloud.create_token(api, "tenant-abc", "2w", "full-access"))
      case token_result {
        Ok(token) -> io.println("Token: " <> token.jwt)
        Error(e) -> io.println_error(error.to_string(e))
      }
    }
    Error(e) -> io.println_error(error.to_string(e))
  }

  // List all databases
  use result <- promise.await(cloud.list_databases(api))

  // Delete a database
  use _ <- promise.await(cloud.delete_database(api, "tenant-abc"))

  // Group management
  use _ <- promise.await(cloud.create_group(api, "my-group"))
  use result <- promise.await(cloud.list_groups(api))
}
```

### DB Toolchain (SQL Code Generation)

Write SQL in `*.sql` files with type annotations, and gflare generates typed Gleam functions.

**SQL File Format:**

```sql
-- src/my_app/sql/find_user.sql
-- params: user_id: Int
-- returns: id: Int, name: String, email: Option(String)
SELECT id, name, email FROM users WHERE id = ?1
```

```sql
-- src/my_app/sql/create_user.sql
-- params: name: String, email: String
INSERT INTO users (name, email) VALUES (?1, ?2)
```

**Generate Code:**

```bash
gleam run -m gflare -- db generate
# Generated 2 functions in src/my_app/sql.gleam
```

**Generated Code (D1 backend):**

```gleam
// AUTO-GENERATED - src/my_app/sql.gleam
import gleam/dynamic/decode
import gleam/javascript/promise
import gleam/option.{type Option, None, Some}
import gflare/d1
import gflare/error.{type Error}

pub type FindUserRow {
  FindUserRow(id: Int, name: String, email: Option(String))
}

pub fn find_user(db: d1.Database, user_id: Int) -> promise.Promise(Result(FindUserRow, Error)) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use name <- decode.field(1, decode.string)
    use email <- decode.optional_field(2, "", decode.string)
    decode.success(FindUserRow(id:, name:, email:))
  }
  use result <- promise.await(d1.prepare(db, "SELECT id, name, email FROM users WHERE id = ?1")
  |> d1.bind([d1.int(user_id)])
  |> d1.first())
  case result {
    Ok(Some(row)) -> decode.run(row, decoder)
    Ok(None) -> promise.resolve(Error(error.D1Error("No row found")))
    Error(e) -> promise.resolve(Error(e))
  }
}
```

**Generated Code (Turso backend):**

```bash
gleam run -m gflare -- db generate --backend turso
```

```gleam
// AUTO-GENERATED
import gflare/turso
import gflare/turso/error.{type TursoError}

pub fn find_user(config: turso.Config, user_id: Int) -> promise.Promise(Result(FindUserRow, TursoError)) {
  turso.execute(config, "SELECT id, name, email FROM users WHERE id = ?1", [turso.int(user_id)])
}
```

**Supported Types:**

| SQL Annotation | Gleam Type |
|----------------|------------|
| `Int` | `Int` |
| `Float` | `Float` |
| `String` | `String` |
| `Bool` | `Bool` |
| `BitArray` | `BitArray` |
| `Option(Int)` | `Option(Int)` |
| `Option(String)` | `Option(String)` |

**Migrations:**

```bash
# Create a migration
gleam run -m gflare -- db migrate create create_users_table
# Creates db/migrations/0001_create_users_table.sql

# List migrations
gleam run -m gflare -- db migrate list

# Apply migrations
gleam run -m gflare -- db migrate run
```

Migration files use sequential numbering:

```
db/migrations/
  0001_create_users_table.sql
  0002_add_email_index.sql
  0003_create_posts.sql
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
      use text <- promise.await(r2.read_text(body))
      case text {
        Ok(content) -> response.new(200) |> response.set_body(content) |> promise.resolve
        Error(e) -> response.new(500) |> response.set_body(error.to_string(e)) |> promise.resolve
      }
    }
    Error(_) -> response.new(404) |> response.set_body("File not found") |> promise.resolve
  }
}
```

```gleam
// Upload file
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
```

```gleam
// List files
let opts = r2.list_options_with(prefix: Some("uploads/"), cursor: None, delimiter: None, limit: Some(100), include: None)
use result <- promise.await(r2.list(bucket, opts))

// Delete file
use _ <- promise.await(r2.delete(bucket, "old-file.txt"))

// Get metadata
use result <- promise.await(r2.head(bucket, "file.txt"))
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
}

// Consumer: process messages
pub fn queue(batch, env: Env, ctx: Context) {
  list.each(batch.messages, fn(msg) {
    let body = queue.message_body(msg)
    let id = queue.message_id(msg)
    let attempts = queue.message_attempts(msg)
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
```

```gleam
// Set a value
use _ <- promise.await(durable_object.set(stub, "count", json.int(1)))

// Set alarm 60 seconds from now
let timestamp = 1_700_000_000_000 + 60_000
use _ <- promise.await(durable_object.set_alarm(stub, timestamp))

// Get alarm
use result <- promise.await(durable_object.get_alarm(stub))
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
      let assert Ok(name) = decode.run(data, decode.field("name", decode.string, decode.success))
      response.new(200) |> response.set_body("Hello " <> name) |> promise.resolve
    }
    Error(e) -> response.new(400) |> response.set_body(e) |> promise.resolve
  }
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
```

## Error Handling

All binding operations return `Result(T, gflare/error.Error)`:

```gleam
import gflare/error

case result {
  Ok(value) -> // use value
  Error(err) -> io.println_error(error.to_string(err))
}
```

**Error Variants:**

```gleam
pub type Error {
  KvError(message: String)
  D1Error(message: String)
  R2Error(message: String)
  DurableObjectError(message: String)
  QueueError(message: String)
  BindingNotFound(name: String)
  EncodingError(message: String)
  DecodingError(message: String)
}
```

**Turso Error Variants:**

```gleam
pub type TursoError {
  ApiError(message: String)
  NotFound(name: String)
  Conflict(name: String)
  NetworkError(message: String)
  DecodeError(message: String)
}
```

## Full Example

A complete worker with KV caching and D1 database:

```gleam
import gflare/bindings.{type Env}
import gflare/worker.{type Context}
import gflare/request.{type HttpRequest}
import gflare/response
import gflare/kv
import gflare/d1
import gleam/dynamic/decode
import gleam/json
import gleam/list

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
  let assert Ok(db) = bindings.d1(env, "DB")

  // Try KV cache first
  use cached <- promise.await(kv.get(cache, "users", kv.get_options()))
  case cached {
    Ok(json_str) -> {
      // Cache hit
      let assert Ok(data) = json_util.parse(json_str)
      response.new(200) |> response.json(data) |> promise.resolve
    }
    Error(_) -> {
      // Cache miss — query D1
      let stmt = d1.prepare(db, "SELECT id, name, email FROM users")
      use result <- promise.await(d1.all(stmt))
      case result {
        Ok(result) -> {
          let users = list.map(result.results, fn(row) {
            let assert Ok(user) = decode.run(row, user_decoder())
            user
          })
          let json_data = json.array(users, user_to_json)
          // Cache for 5 minutes
          let cache_opts = kv.put_options_with(expiration: None, expiration_ttl: Some(300))
          use _ <- promise.await(kv.put(cache, "users", json_stringify(json_data), cache_opts))
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
