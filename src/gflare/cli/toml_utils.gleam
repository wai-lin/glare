import gleam/dict
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import simplifile
import tom.{type Toml}

pub type Config {
  Config(
    package_name: String,
    worker_name: String,
    compatibility_date: String,
    bindings: CfBindings,
    durable_objects: CfDoConfig,
    vars: dict.Dict(String, String),
  )
}

pub type CfBindings {
  CfBindings(
    kv: List(String),
    d1: List(D1Binding),
    r2: List(String),
    queues_producers: List(String),
    queues_consumers: List(String),
  )
}

pub type D1Binding {
  D1Binding(
    binding: String,
    database_name: Option(String),
    database_id: Option(String),
    migrations_dir: Option(String),
  )
}

pub type CfDoConfig {
  CfDoConfig(classes: List(DoClass))
}

pub type DoClass {
  DoClass(name: String, class_name: String)
}

// --- Public API ---

pub fn load_config() -> Result(Config, String) {
  use package_name <- result.try(load_package_name())
  use config <- result.try(load_wrangler_config())
  Ok(Config(..config, package_name:))
}

pub fn load_package_name() -> Result(String, String) {
  use content <- result.try(
    simplifile.read("gleam.toml")
    |> result.map_error(fn(_) { "Could not read gleam.toml" }),
  )
  use parsed <- result.try(
    tom.parse(content)
    |> result.map_error(fn(err) { "TOML parse error: " <> string.inspect(err) }),
  )
  tom.get_string(parsed, ["name"])
  |> result.map_error(fn(_) { "Missing 'name' in gleam.toml" })
}

pub fn load_wrangler_config() -> Result(Config, String) {
  use content <- result.try(
    simplifile.read("wrangler.toml")
    |> result.map_error(fn(_) {
      "Could not read wrangler.toml. Run 'gflare init' first."
    }),
  )
  parse_wrangler(content)
}

pub fn parse_wrangler(content: String) -> Result(Config, String) {
  use parsed <- result.try(
    tom.parse(content)
    |> result.map_error(fn(err) { "TOML parse error: " <> string.inspect(err) }),
  )

  use worker_name <- result.try(
    tom.get_string(parsed, ["name"])
    |> result.map_error(fn(_) { "Missing 'name' in wrangler.toml" }),
  )

  let compatibility_date = case tom.get_string(parsed, ["compatibility_date"]) {
    Ok(d) -> d
    Error(_) -> ""
  }

  let bindings = parse_wrangler_bindings(parsed)
  let do_config = parse_wrangler_do_config(parsed)
  let vars = parse_wrangler_vars(parsed)

  Ok(Config(
    package_name: "",
    worker_name:,
    compatibility_date:,
    bindings:,
    durable_objects: do_config,
    vars:,
  ))
}

// --- Wrangler.toml parsing ---

fn parse_wrangler_bindings(table: dict.Dict(String, Toml)) -> CfBindings {
  CfBindings(
    kv: parse_wrangler_kv(table),
    d1: parse_wrangler_d1(table),
    r2: parse_wrangler_r2(table),
    queues_producers: parse_wrangler_queue_producers(table),
    queues_consumers: parse_wrangler_queue_consumers(table),
  )
}

fn parse_wrangler_kv(table: dict.Dict(String, Toml)) -> List(String) {
  extract_binding_names(table, "kv_namespaces")
}

fn parse_wrangler_d1(table: dict.Dict(String, Toml)) -> List(D1Binding) {
  case tom.get(table, ["d1_databases"]) {
    Ok(tom.ArrayOfTables(tables)) ->
      list.filter_map(tables, fn(t) {
        use binding <- result.try(get_string_from_dict(t, ["binding"]))
        let database_name = get_optional_string(t, ["database_name"])
        let database_id = get_optional_string(t, ["database_id"])
        let migrations_dir = get_optional_string(t, ["migrations_dir"])
        Ok(D1Binding(binding:, database_name:, database_id:, migrations_dir:))
      })
    Ok(tom.Array(items)) ->
      list.filter_map(items, fn(item) {
        use t <- result.try(case tom.as_table(item) {
          Ok(t) -> Ok(t)
          Error(_) -> Error("Not a table")
        })
        use binding <- result.try(get_string_from_dict(t, ["binding"]))
        let database_name = get_optional_string(t, ["database_name"])
        let database_id = get_optional_string(t, ["database_id"])
        let migrations_dir = get_optional_string(t, ["migrations_dir"])
        Ok(D1Binding(binding:, database_name:, database_id:, migrations_dir:))
      })
    _ -> []
  }
}

fn parse_wrangler_r2(table: dict.Dict(String, Toml)) -> List(String) {
  extract_binding_names(table, "r2_buckets")
}

fn parse_wrangler_queue_producers(
  table: dict.Dict(String, Toml),
) -> List(String) {
  case tom.get(table, ["queues"]) {
    Ok(queues_table) ->
      extract_binding_names_from(queues_table, "producers", "binding")
    Error(_) -> []
  }
}

fn parse_wrangler_queue_consumers(
  table: dict.Dict(String, Toml),
) -> List(String) {
  case tom.get(table, ["queues"]) {
    Ok(queues_table) ->
      extract_binding_names_from(queues_table, "consumers", "queue")
    Error(_) -> []
  }
}

fn parse_wrangler_do_config(table: dict.Dict(String, Toml)) -> CfDoConfig {
  case tom.get(table, ["durable_objects"]) {
    Ok(tom.Table(do_table)) -> parse_do_bindings_from_table(do_table)
    _ -> CfDoConfig(classes: [])
  }
}

fn parse_do_bindings_from_table(
  do_table: dict.Dict(String, Toml),
) -> CfDoConfig {
  case tom.get(do_table, ["bindings"]) {
    Ok(tom.ArrayOfTables(tables)) -> {
      let classes =
        list.filter_map(tables, fn(t) {
          use name <- result.try(get_string_from_dict(t, ["name"]))
          use class_name <- result.try(get_string_from_dict(t, ["class_name"]))
          Ok(DoClass(name:, class_name:))
        })
      CfDoConfig(classes:)
    }
    Ok(tom.Array(items)) -> {
      let classes =
        list.filter_map(items, fn(item) {
          use t <- result.try(case tom.as_table(item) {
            Ok(t) -> Ok(t)
            Error(_) -> Error("Not a table")
          })
          use name <- result.try(get_string_from_dict(t, ["name"]))
          use class_name <- result.try(get_string_from_dict(t, ["class_name"]))
          Ok(DoClass(name:, class_name:))
        })
      CfDoConfig(classes:)
    }
    _ -> CfDoConfig(classes: [])
  }
}

fn parse_wrangler_vars(
  table: dict.Dict(String, Toml),
) -> dict.Dict(String, String) {
  case tom.get(table, ["vars"]) {
    Ok(tom.Table(vars_table)) ->
      dict.fold(vars_table, dict.new(), fn(acc, key, value) {
        case tom.as_string(value) {
          Ok(s) -> dict.insert(acc, key, s)
          Error(_) -> acc
        }
      })
    _ -> dict.new()
  }
}

// --- Helpers ---

fn extract_binding_names(
  table: dict.Dict(String, Toml),
  table_name: String,
) -> List(String) {
  case tom.get(table, [table_name]) {
    Ok(tom.ArrayOfTables(tables)) ->
      list.filter_map(tables, fn(t) { get_string_from_dict(t, ["binding"]) })
    Ok(tom.Array(items)) ->
      list.filter_map(items, fn(item) {
        use t <- result.try(case tom.as_table(item) {
          Ok(t) -> Ok(t)
          Error(_) -> Error("Not a table")
        })
        get_string_from_dict(t, ["binding"])
      })
    _ -> []
  }
}

fn extract_binding_names_from(
  parent: Toml,
  child_name: String,
  field: String,
) -> List(String) {
  case parent {
    tom.Table(table) -> {
      case tom.get(table, [child_name]) {
        Ok(tom.ArrayOfTables(tables)) ->
          list.filter_map(tables, fn(t) { get_string_from_dict(t, [field]) })
        Ok(tom.Array(items)) ->
          list.filter_map(items, fn(item) {
            use t <- result.try(case tom.as_table(item) {
              Ok(t) -> Ok(t)
              Error(_) -> Error("Not a table")
            })
            get_string_from_dict(t, [field])
          })
        _ -> []
      }
    }
    _ -> []
  }
}

fn get_string_from_dict(
  table: dict.Dict(String, Toml),
  path: List(String),
) -> Result(String, String) {
  tom.get_string(table, path)
  |> result.map_error(fn(_) { "Key not found: " <> string.join(path, ".") })
}

fn get_optional_string(
  table: dict.Dict(String, Toml),
  path: List(String),
) -> Option(String) {
  case tom.get_string(table, path) {
    Ok(value) -> Some(value)
    Error(_) -> None
  }
}
