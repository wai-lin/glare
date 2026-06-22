import gleam/dynamic/decode
import gleam/io
import gleam/javascript/promise.{type Promise}
import gleam/list
import gleam/order.{type Order, Eq, Gt, Lt}
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import gflare/d1
import gflare/error
import gflare/turso
import gflare/turso/error.{type TursoError} as turso_error
import gflare/turso/types as turso_types
import simplifile

const tracking_table = "_gflare_migrations"

pub type Migration {
  Migration(version: Int, name: String, path: String, sql: String)
}

pub fn run_turso(
  config: turso.Config,
  migrations_dir: String,
) -> Promise(Result(Nil, String)) {
  use _ <- promise.await(ensure_tracking_table_turso(config))
  use applied <- promise.await(list_applied_turso(config))
  case applied {
    Error(e) -> promise.resolve(Error(e))
    Ok(applied) -> {
      case list_pending(migrations_dir, applied) {
        Error(e) -> promise.resolve(Error(e))
        Ok(pending) -> execute_pending_turso(config, pending)
      }
    }
  }
}

pub fn run_d1(
  db: d1.Database,
  migrations_dir: String,
) -> Promise(Result(Nil, String)) {
  use _ <- promise.await(ensure_tracking_table_d1(db))
  use applied <- promise.await(list_applied_d1(db))
  case applied {
    Error(e) -> promise.resolve(Error(e))
    Ok(applied) -> {
      case list_pending(migrations_dir, applied) {
        Error(e) -> promise.resolve(Error(e))
        Ok(pending) -> execute_pending_d1(db, pending)
      }
    }
  }
}

fn ensure_tracking_table_turso(
  config: turso.Config,
) -> Promise(Result(Nil, String)) {
  let sql =
    "CREATE TABLE IF NOT EXISTS "
    <> tracking_table
    <> " (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL UNIQUE, applied_at TEXT DEFAULT (datetime('now')))"
  use result <- promise.await(turso.execute(config, sql, []))
  case result {
    Ok(_) -> promise.resolve(Ok(Nil))
    Error(e) ->
      promise.resolve(Error("Failed to create tracking table: " <> turso_error.to_string(e)))
  }
}

fn ensure_tracking_table_d1(db: d1.Database) -> Promise(Result(Nil, String)) {
  let sql =
    "CREATE TABLE IF NOT EXISTS "
    <> tracking_table
    <> " (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL UNIQUE, applied_at TEXT DEFAULT (datetime('now')))"
  use result <- promise.await(d1.exec(db, sql))
  case result {
    Ok(_) -> promise.resolve(Ok(Nil))
    Error(e) ->
      promise.resolve(Error("Failed to create tracking table: " <> error.to_string(e)))
  }
}

fn list_applied_turso(
  config: turso.Config,
) -> Promise(Result(List(String), String)) {
  let sql = "SELECT name FROM " <> tracking_table <> " ORDER BY id"
  use result <- promise.await(turso.execute(config, sql, []))
  case result {
    Ok(execute_result) -> {
      let names =
        list.filter_map(execute_result.rows, fn(row) {
          case row.values {
            [turso_types.Text(name), ..] -> Ok(name)
            _ -> Error(Nil)
          }
        })
      promise.resolve(Ok(names))
    }
    Error(e) ->
      promise.resolve(Error("Failed to list applied migrations: " <> turso_error.to_string(e)))
  }
}

fn list_applied_d1(
  db: d1.Database,
) -> Promise(Result(List(String), String)) {
  let stmt = d1.prepare(db, "SELECT name FROM " <> tracking_table <> " ORDER BY id")
  use result <- promise.await(d1.first(stmt))
  case result {
    Ok(Some(row)) -> {
      let decoder = {
        use name <- decode.field("name", decode.string)
        decode.success(name)
      }
      case decode.run(row, decoder) {
        Ok(name) -> promise.resolve(Ok([name]))
        Error(_) -> promise.resolve(Ok([]))
      }
    }
    Ok(None) -> promise.resolve(Ok([]))
    Error(e) ->
      promise.resolve(Error("Failed to list applied migrations: " <> error.to_string(e)))
  }
}

fn list_pending(
  migrations_dir: String,
  applied: List(String),
) -> Result(List(Migration), String) {
  use files <- result.try(
    simplifile.get_files(migrations_dir)
    |> result.map_error(fn(_) { "Failed to read migrations directory" }),
  )

  let migrations =
    files
    |> list.filter(fn(f) { string.ends_with(f, ".sql") })
    |> list.filter_map(fn(f) {
      case parse_migration_file(f) {
        Ok(migration) -> {
          let is_applied = list.any(applied, fn(a) { a == migration.name })
          case is_applied {
            True -> Error(Nil)
            False -> Ok(migration)
          }
        }
        Error(_) -> Error(Nil)
      }
    })
    |> list.sort(fn(a, b) { int_compare(a.version, b.version) })

  Ok(migrations)
}

fn execute_pending_turso(
  config: turso.Config,
  pending: List(Migration),
) -> Promise(Result(Nil, String)) {
  case pending {
    [] -> {
      io.println("No pending migrations.")
      promise.resolve(Ok(Nil))
    }
    _ -> {
      io.println("Applying " <> int_to_string(list.length(pending)) <> " migration(s)...")
      execute_migrations_turso(config, pending)
    }
  }
}

fn execute_migrations_turso(
  config: turso.Config,
  migrations: List(Migration),
) -> Promise(Result(Nil, String)) {
  case migrations {
    [] -> promise.resolve(Ok(Nil))
    [migration, ..rest] -> {
      io.println("  Applying: " <> migration.name)
      use result <- promise.await(turso.execute(config, migration.sql, []))
      case result {
        Ok(_) -> {
          use _ <- promise.await(record_migration_turso(config, migration.name))
          execute_migrations_turso(config, rest)
        }
        Error(e) ->
          promise.resolve(
            Error("Failed to apply migration " <> migration.name <> ": " <> turso_error.to_string(e)),
          )
      }
    }
  }
}

fn record_migration_turso(
  config: turso.Config,
  name: String,
) -> Promise(Result(Nil, String)) {
  let sql = "INSERT INTO " <> tracking_table <> " (name) VALUES (?)"
  use result <- promise.await(turso.execute(config, sql, [turso.text(name)]))
  case result {
    Ok(_) -> promise.resolve(Ok(Nil))
    Error(e) ->
      promise.resolve(
        Error("Failed to record migration " <> name <> ": " <> turso_error.to_string(e)),
      )
  }
}

fn execute_pending_d1(
  db: d1.Database,
  pending: List(Migration),
) -> Promise(Result(Nil, String)) {
  case pending {
    [] -> {
      io.println("No pending migrations.")
      promise.resolve(Ok(Nil))
    }
    _ -> {
      io.println("Applying " <> int_to_string(list.length(pending)) <> " migration(s)...")
      execute_migrations_d1(db, pending)
    }
  }
}

fn execute_migrations_d1(
  db: d1.Database,
  migrations: List(Migration),
) -> Promise(Result(Nil, String)) {
  case migrations {
    [] -> promise.resolve(Ok(Nil))
    [migration, ..rest] -> {
      io.println("  Applying: " <> migration.name)
      use result <- promise.await(d1.exec(db, migration.sql))
      case result {
        Ok(_) -> {
          use _ <- promise.await(record_migration_d1(db, migration.name))
          execute_migrations_d1(db, rest)
        }
        Error(e) ->
          promise.resolve(
            Error("Failed to apply migration " <> migration.name <> ": " <> error.to_string(e)),
          )
      }
    }
  }
}

fn record_migration_d1(
  db: d1.Database,
  name: String,
) -> Promise(Result(Nil, String)) {
  let stmt = d1.prepare(db, "INSERT INTO " <> tracking_table <> " (name) VALUES (?)")
  let stmt = d1.bind(stmt, [d1.text(name)])
  use result <- promise.await(d1.run(stmt))
  case result {
    Ok(_) -> promise.resolve(Ok(Nil))
    Error(e) ->
      promise.resolve(
        Error("Failed to record migration " <> name <> ": " <> error.to_string(e)),
      )
  }
}

fn parse_migration_file(path: String) -> Result(Migration, String) {
  let filename = path |> string.split("/") |> list.last |> result.unwrap("")
  let name = filename |> string.replace(".sql", "")

  case parse_version_from_name(name) {
    Ok(version) -> {
      use content <- result.try(
        simplifile.read(path)
        |> result.map_error(fn(_) { "Failed to read " <> path }),
      )

      let sql =
        content
        |> string.split("\n")
        |> list.filter(fn(line) {
          let trimmed = string.trim(line)
          trimmed != "" && !string.starts_with(trimmed, "--")
        })
        |> string.join("\n")

      case sql {
        "" -> Error("Empty SQL in " <> path)
        _ -> Ok(Migration(version:, name:, path:, sql:))
      }
    }
    Error(_) -> Error("Invalid migration filename: " <> filename)
  }
}

fn parse_version_from_name(name: String) -> Result(Int, Nil) {
  case string.split(name, "_") {
    [version_str, ..] -> parse_version(version_str)
    _ -> Error(Nil)
  }
}

fn parse_version(s: String) -> Result(Int, Nil) {
  let digits = string.to_graphemes(s)
  list.try_fold(digits, 0, fn(acc, c) {
    case c {
      "0" -> Ok(acc * 10)
      "1" -> Ok(acc * 10 + 1)
      "2" -> Ok(acc * 10 + 2)
      "3" -> Ok(acc * 10 + 3)
      "4" -> Ok(acc * 10 + 4)
      "5" -> Ok(acc * 10 + 5)
      "6" -> Ok(acc * 10 + 6)
      "7" -> Ok(acc * 10 + 7)
      "8" -> Ok(acc * 10 + 8)
      "9" -> Ok(acc * 10 + 9)
      _ -> Error(Nil)
    }
  })
}

fn int_compare(a: Int, b: Int) -> Order {
  case a < b {
    True -> Lt
    False ->
      case a > b {
        True -> Gt
        False -> Eq
      }
  }
}

fn int_to_string(n: Int) -> String {
  case n {
    0 -> "0"
    _ -> {
      let digit = n % 10
      let rest = n / 10
      case rest {
        0 -> digit_char(digit)
        _ -> int_to_string(rest) <> digit_char(digit)
      }
    }
  }
}

fn digit_char(d: Int) -> String {
  case d {
    0 -> "0"
    1 -> "1"
    2 -> "2"
    3 -> "3"
    4 -> "4"
    5 -> "5"
    6 -> "6"
    7 -> "7"
    8 -> "8"
    9 -> "9"
    _ -> "0"
  }
}
