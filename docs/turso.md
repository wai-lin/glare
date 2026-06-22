# Turso (Database over HTTP)

Turso is a SQLite-compatible database that runs over HTTP. Use it when you want a database without Cloudflare D1, or need multi-region replication.

## Basic Usage

### Connect and query

```gleam
import gflare/bindings
import gflare/turso
import gflare/turso/error as turso_err
import gflare/response
import gleam/javascript/promise

pub fn fetch(request, env, ctx) {
  // Get connection details from environment
  case bindings.var(env, "TURSO_DATABASE_URL"), bindings.secret(env, "TURSO_AUTH_TOKEN") {
    Ok(url), Ok(token) -> {
      let config = turso.connect(url, token)

      // Execute a query
      use result <- promise.await(turso.execute(config, "SELECT * FROM users", []))
      case result {
        Ok(result) -> {
          // result.rows: List(Row)
          // result.columns: List(String)
          // result.rows_affected: Int
          response.new(200)
          |> response.set_body("Found users")
          |> promise.resolve
        }
        Error(e) -> {
          response.new(500)
          |> response.set_body(turso_err.to_string(e))
          |> promise.resolve
        }
      }
    }
    _, _ -> {
      response.new(500)
      |> response.set_body("Missing TURSO_DATABASE_URL or TURSO_AUTH_TOKEN")
      |> promise.resolve
    }
  }
}
```

### Query with parameters

```gleam
use result <- promise.await(turso.execute(
  config,
  "SELECT * FROM users WHERE id = ?",
  [turso.int(42)],
))
case result {
  Ok(result) -> {
    // Access rows
    list.each(result.rows, fn(row) {
      io.println("Row: " <> string.inspect(row.values))
    })
  }
  Error(e) -> io.println_error(turso_err.to_string(e))
}
```

### Batch execution

```gleam
use result <- promise.await(turso.batch(
  config,
  [
    #("INSERT INTO users (name) VALUES (?)", [turso.text("Alice")]),
    #("INSERT INTO users (name) VALUES (?)", [turso.text("Bob")]),
  ],
  turso.Write,
))
case result {
  Ok(results) -> {
    // results is List(ExecuteResult)
    io.println("Inserted " <> int.to_string(list.length(results)) <> " rows")
  }
  Error(e) -> io.println_error(turso_err.to_string(e))
}
```

### Transaction

```gleam
// Transactions roll back on any error
use result <- promise.await(turso.transaction(config, [
  #("UPDATE accounts SET balance = balance - 100 WHERE id = 1", []),
  #("UPDATE accounts SET balance = balance + 100 WHERE id = 2", []),
]))
case result {
  Ok(_) -> io.println("Transfer complete!")
  Error(e) -> io.println_error("Transfer failed: " <> turso_err.to_string(e))
}
```

## Value Constructors

Create typed values for parameters:

```gleam
turso.int(42)              // Integer
turso.float(3.14)          // Float
turso.text("hello")        // Text
turso.blob(<<1, 2, 3>>)    // Blob (sent as base64)
turso.null_value()         // Null
turso.date("2025-01-15")   // Date (stored as text)
turso.time("14:30:00")     // Time (stored as text)
turso.timestamp("2025-01-15T14:30:00Z") // Timestamp (stored as text)
turso.uuid("550e8400-...") // UUID (stored as text)
turso.json_string("{\"key\": \"value\"}") // JSON (stored as text)
```

## Configuration

Turso doesn't use Cloudflare bindings. Instead, use environment variables:

```toml
[cloudflare.vars]
TURSO_DATABASE_URL = "lib://my-db.turso.io"
```

Set the auth token as a secret:

```bash
wrangler secret put TURSO_AUTH_TOKEN
```

Then access in code:

```gleam
case bindings.var(env, "TURSO_DATABASE_URL"), bindings.secret(env, "TURSO_AUTH_TOKEN") {
  Ok(url), Ok(token) -> {
    let config = turso.connect(url, token)
    use_config(config)
  }
  _, _ -> handle_missing_config()
}
```

## Error Handling

Turso uses its own error type:

```gleam
pub type TursoError {
  ApiError(message: String)       // API returned an error
  NotFound(name: String)          // Resource not found
  Conflict(name: String)          // Resource already exists
  NetworkError(message: String)   // Network request failed
  DecodeError(message: String)    // Response couldn't be parsed
}
```

Convert to string with `turso_err.to_string(e)`.

## Platform API

The Platform API lets you manage Turso databases programmatically. Use it for multi-tenant SaaS, automated database provisioning, or infrastructure management.

### Setup

```gleam
import gflare/turso/cloud
import gflare/turso/error as turso_err

// Create a CloudConfig with your org and platform API token
let api = cloud.connect("my-org", "platform-api-token")
```

### Database Management

#### Create a database

```gleam
use result <- promise.await(cloud.create_database(api, "tenant-abc", "default"))
case result {
  Ok(db) -> {
    // db.name, db.db_id, db.hostname, db.group, db.primary_region
    io.println("Created: " <> db.hostname)
  }
  Error(e) -> io.println_error(turso_err.to_string(e))
}
```

#### List all databases

```gleam
use result <- promise.await(cloud.list_databases(api))
case result {
  Ok(databases) -> {
    list.each(databases, fn(db) {
      io.println(db.name <> " - " <> db.hostname)
    })
  }
  Error(e) -> io.println_error(turso_err.to_string(e))
}
```

#### Get database info

```gleam
use result <- promise.await(cloud.retrieve_database(api, "tenant-abc"))
case result {
  Ok(db) -> io.println("Hostname: " <> db.hostname)
  Error(e) -> io.println_error(turso_err.to_string(e))
}
```

#### Delete a database

```gleam
use result <- promise.await(cloud.delete_database(api, "tenant-abc"))
case result {
  Ok(Nil) -> io.println("Deleted!")
  Error(e) -> io.println_error(turso_err.to_string(e))
}
```

### Token Management

Create scoped auth tokens for database access:

```gleam
use result <- promise.await(cloud.create_token(api, "tenant-abc", "2w", "full-access"))
case result {
  Ok(token) -> {
    // token.jwt is the auth token
    let config = turso.connect("lib://" <> db.hostname, token.jwt)
    // Use config for database operations
  }
  Error(e) -> io.println_error(turso_err.to_string(e))
}
```

Token expiration formats: `"1h"`, `"2w"`, `"10y"` (hours, weeks, years).
Authorization levels: `"full-access"`, `"read-only"`.

### Group Management

```gleam
// Create a group
use _ <- promise.await(cloud.create_group(api, "my-group"))

// List all groups
use result <- promise.await(cloud.list_groups(api))
case result {
  Ok(groups) -> {
    list.each(groups, fn(group) {
      io.println(group.name <> " - " <> group.location)
    })
  }
  Error(e) -> io.println_error(turso_err.to_string(e))
}

// Delete a group
use _ <- promise.await(cloud.delete_group(api, "my-group"))
```

### Multi-Tenant Example

Create a new tenant with database and migrations:

```gleam
import gflare/migrate
import gflare/turso
import gflare/turso/cloud
import gflare/turso/error as turso_err

pub fn create_tenant(api, tenant_id) {
  // 1. Create database
  use result <- promise.await(cloud.create_database(api, tenant_id, "default"))
  case result {
    Error(e) -> promise.resolve(Error(e))
    Ok(db) -> {
      // 2. Generate auth token
      use token_result <- promise.await(
        cloud.create_token(api, tenant_id, "10y", "full-access"),
      )
      case token_result {
        Error(e) -> promise.resolve(Error(e))
        Ok(token) -> {
          // 3. Connect and apply migrations
          let config = turso.connect("lib://" <> db.hostname, token.jwt)
          use _ <- promise.await(migrate.run_turso(config, "db/migrations"))
          promise.resolve(Ok(Nil))
        }
      }
    }
  }
}
```

### Platform API Functions

| Function | Returns | Description |
|----------|---------|-------------|
| `cloud.connect(org, token)` | `CloudConfig` | Create API config |
| `cloud.create_database(config, name, group)` | `Promise(Result(Database, TursoError))` | Create a database |
| `cloud.delete_database(config, name)` | `Promise(Result(Nil, TursoError))` | Delete a database |
| `cloud.retrieve_database(config, name)` | `Promise(Result(Database, TursoError))` | Get database info |
| `cloud.list_databases(config)` | `Promise(Result(List(Database), TursoError))` | List all databases |
| `cloud.create_token(config, db_name, expiration, authorization)` | `Promise(Result(TokenResult, TursoError))` | Create auth token |
| `cloud.create_group(config, name)` | `Promise(Result(Group, TursoError))` | Create a group |
| `cloud.delete_group(config, name)` | `Promise(Result(Nil, TursoError))` | Delete a group |
| `cloud.list_groups(config)` | `Promise(Result(List(Group), TursoError))` | List all groups |

## Related

- [Platform API](#platform-api) — manage databases programmatically
- [Code Generation](code-generation.md) — auto-generate typed functions from SQL
- [Migrations](migrations.md) — manage database schema
- [Error Handling](error-handling.md) — error handling patterns
