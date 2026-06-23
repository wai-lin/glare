import gleam/int
import gleam/list
import gleam/result
import gleam/string
import simplifile

pub type Migration {
  Migration(version: Int, name: String, path: String, sql: String)
}

pub fn parse_migration_file(path: String) -> Result(Migration, String) {
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

pub fn parse_version_from_name(name: String) -> Result(Int, Nil) {
  case string.split(name, "_") {
    [version_str, ..] -> int.parse(version_str)
    _ -> Error(Nil)
  }
}

pub fn list_pending(
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
    |> list.sort(fn(a, b) { int.compare(a.version, b.version) })

  Ok(migrations)
}
