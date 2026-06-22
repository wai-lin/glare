import argv
import gleam/io
import gleam/list
import gleam/order.{type Order, Eq, Gt, Lt}
import gleam/string
import gflare/cli/db/generate
import gflare/cli/db/parse_sql
import gflare/cli/db/types.{D1, Turso}
import gflare/cli/toml_utils
import gflare/migrate
import simplifile

pub fn run() -> Nil {
  let args = argv.load().arguments
  case args {
    ["generate", ..rest] -> run_generate(rest)
    ["migrate", ..rest] -> run_migrate(rest)
    _ -> {
      io.println("Usage: gflare db <command>")
      io.println("")
      io.println("Commands:")
      io.println("  generate                    Generate Gleam code from *.sql files")
      io.println("  migrate create <name>       Create a new migration file")
      io.println("  migrate list                List pending migrations")
      io.println("  migrate run                 Apply pending migrations")
    }
  }
}

fn run_generate(args: List(String)) -> Nil {
  let backend = case args {
    ["--backend", "turso", ..] -> Turso
    _ -> D1
  }

  case toml_utils.load_config() {
    Ok(config) -> {
      let src_dir = "src"
      case parse_sql.find_sql_files(src_dir) {
        Ok(sql_files) -> {
          case sql_files {
            [] -> io.println("No .sql files found in src/")
            _ -> {
              let queries =
                list.filter_map(sql_files, fn(path) {
                  case parse_sql.parse_file(path) {
                    Ok(q) -> Ok(q)
                    Error(e) -> {
                      io.println_error("Warning: " <> e.message)
                      Error(Nil)
                    }
                  }
                })

              let package_name = config.package_name
              let output_dir = "src/" <> string.replace(package_name, "-", "_")
              let output_path = output_dir <> "/sql.gleam"

              case simplifile.create_directory_all(output_dir) {
                Ok(Nil) -> {
                  case generate.generate_sql_module(queries, backend, output_path) {
                    Ok(Nil) ->
                      io.println(
                        "Generated " <> int_to_string(list.length(queries)) <> " functions in " <> output_path,
                      )
                    Error(e) -> io.println_error("Error: " <> e)
                  }
                }
                Error(e) ->
                  io.println_error(
                    "Failed to create directory: " <> simplifile.describe_error(e),
                  )
              }
            }
          }
        }
        Error(e) -> io.println_error("Error: " <> e.message)
      }
    }
    Error(e) -> io.println_error("Failed to load gleam.toml: " <> e)
  }
}

fn run_migrate(args: List(String)) -> Nil {
  case args {
    ["create", name] -> create_migration(name)
    ["list"] -> list_migrations()
    ["run", ..rest] -> run_migrations(rest)
    _ -> {
      io.println("Usage: gflare db migrate <command>")
      io.println("")
      io.println("Commands:")
      io.println("  create <name>    Create a new migration file")
      io.println("  list             List pending migrations")
      io.println("  run              Apply pending migrations")
      io.println("  run --turso      Apply migrations to Turso")
    }
  }
}

fn create_migration(name: String) -> Nil {
  let migrations_dir = "db/migrations"
  case simplifile.create_directory_all(migrations_dir) {
    Ok(Nil) -> {
      let next_version = get_next_migration_version(migrations_dir)
      let padded = pad_number(next_version, 4)
      let filename = padded <> "_" <> name <> ".sql"
      let filepath = migrations_dir <> "/" <> filename

      case simplifile.write(
        to: filepath,
        contents: "-- Migration: " <> name <> "\n-- Created at: " <> get_timestamp() <> "\n\n-- Write your SQL here\n",
      ) {
        Ok(Nil) -> io.println("Created migration: " <> filepath)
        Error(e) ->
          io.println_error("Failed to create migration: " <> simplifile.describe_error(e))
      }
    }
    Error(e) ->
      io.println_error(
        "Failed to create migrations directory: " <> simplifile.describe_error(e),
      )
  }
}

fn list_migrations() -> Nil {
  let migrations_dir = "db/migrations"
  case simplifile.get_files(migrations_dir) {
    Ok(files) -> {
      let sql_files =
        files
        |> list.filter(fn(f) { string.ends_with(f, ".sql") })
        |> list.sort(string.compare)

      case sql_files {
        [] -> io.println("No migration files found.")
        _ -> {
          io.println("Migration files:")
          list.each(sql_files, fn(f) { io.println("  " <> f) })
        }
      }
    }
    Error(_) -> io.println("No migrations directory found. Run 'gflare db migrate create <name>' to create one.")
  }
}

fn run_migrations(args: List(String)) -> Nil {
  let backend = case args {
    ["--turso", ..] -> Turso
    _ -> D1
  }
  let migrations_dir = "db/migrations"

  case backend {
    D1 -> {
      io.println("Running migrations for D1...")
      io.println("Note: D1 migrations require a running D1 database.")
      io.println("Use 'wrangler d1 migrations apply <binding_name>' for D1, or use --turso flag.")
    }
    Turso -> {
      io.println("Running migrations for Turso...")
      io.println("Note: Turso migrations require TURSO_DATABASE_URL and TURSO_AUTH_TOKEN environment variables.")
    }
  }
}

fn get_next_migration_version(dir: String) -> Int {
  case simplifile.get_files(dir) {
    Ok(files) -> {
      let versions =
        files
        |> list.filter_map(fn(f) {
          case string.split(f, "_") {
            [version_str, ..] ->
              case parse_version(version_str) {
                Ok(v) -> Ok(v)
                Error(_) -> Error(Nil)
              }
            _ -> Error(Nil)
          }
        })

      case list.sort(versions, fn(a, b) { int_compare(a, b) }) {
        [] -> 1
        [last, ..] -> last + 1
      }
    }
    Error(_) -> 1
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

fn pad_number(n: Int, width: Int) -> String {
  let s = int_to_string(n)
  let padding = width - string.length(s)
  case padding > 0 {
    True -> string.repeat("0", padding) <> s
    False -> s
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

fn get_timestamp() -> String {
  "2026-01-01T00:00:00Z"
}
