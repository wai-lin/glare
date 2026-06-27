import gflare/cli/db/types.{
  type DbBackend, type ParsedQuery, type ResultSet, Both, D1, Turso,
  gleam_type_to_d1_bind, gleam_type_to_decoder, gleam_type_to_string,
  gleam_type_to_turso_value,
}
import gleam/int
import gleam/list
import gleam/string
import simplifile

// Multi-file generation for dual backend support

pub fn generate_sql_modules(
  queries: List(ParsedQuery),
  cli_backend: DbBackend,
  output_dir: String,
  package_name: String,
) -> Result(Nil, String) {
  // Determine which backends are needed
  let needed_backends = determine_backends(queries, cli_backend)
  let is_multi = list.length(needed_backends) > 1

  // Generate shared types if multiple backends
  case is_multi {
    True -> {
      let shared_content = generate_shared_types(queries, package_name)
      case write_file(output_dir <> "/sql_shared.gleam", shared_content) {
        Ok(Nil) ->
          generate_d1_if_needed(
            queries,
            needed_backends,
            is_multi,
            output_dir,
            package_name,
          )
        Error(e) -> Error(e)
      }
    }
    False ->
      generate_d1_if_needed(
        queries,
        needed_backends,
        is_multi,
        output_dir,
        package_name,
      )
  }
}

fn generate_d1_if_needed(
  queries: List(ParsedQuery),
  needed_backends: List(DbBackend),
  is_multi: Bool,
  output_dir: String,
  package_name: String,
) -> Result(Nil, String) {
  case list.contains(needed_backends, D1) {
    True -> {
      let d1_queries = filter_queries_for_backend(queries, D1)
      let d1_content = generate_d1_module(d1_queries, is_multi, package_name)
      case write_file(output_dir <> "/d1_sql.gleam", d1_content) {
        Ok(Nil) ->
          generate_turso_if_needed(
            queries,
            needed_backends,
            is_multi,
            output_dir,
            package_name,
          )
        Error(e) -> Error(e)
      }
    }
    False ->
      generate_turso_if_needed(
        queries,
        needed_backends,
        is_multi,
        output_dir,
        package_name,
      )
  }
}

fn generate_turso_if_needed(
  queries: List(ParsedQuery),
  needed_backends: List(DbBackend),
  is_multi: Bool,
  output_dir: String,
  package_name: String,
) -> Result(Nil, String) {
  case list.contains(needed_backends, Turso) {
    True -> {
      let turso_queries = filter_queries_for_backend(queries, Turso)
      let turso_content =
        generate_turso_module(turso_queries, is_multi, package_name)
      write_file(output_dir <> "/turso_sql.gleam", turso_content)
    }
    False -> Ok(Nil)
  }
}

fn determine_backends(
  queries: List(ParsedQuery),
  cli_backend: DbBackend,
) -> List(DbBackend) {
  let query_backends = list.flat_map(queries, fn(q) { q.backends })
  case cli_backend {
    Turso -> [Turso]
    D1 -> [D1]
    Both -> {
      // Collect unique backends from queries
      let unique = list.unique(query_backends)
      case unique {
        [] -> [D1, Turso]
        _ -> unique
      }
    }
  }
}

fn filter_queries_for_backend(
  queries: List(ParsedQuery),
  backend: DbBackend,
) -> List(ParsedQuery) {
  list.filter(queries, fn(q) { list.contains(q.backends, backend) })
}

fn write_file(path: String, content: String) -> Result(Nil, String) {
  case simplifile.write(to: path, contents: content) {
    Ok(Nil) -> Ok(Nil)
    Error(e) ->
      Error("Failed to write " <> path <> ": " <> simplifile.describe_error(e))
  }
}

fn generate_shared_types(
  queries: List(ParsedQuery),
  _package_name: String,
) -> String {
  let queries_with_returns = list.filter(queries, fn(q) { q.returns != [] })
  let types =
    list.map(queries_with_returns, generate_row_type) |> string.join("\n\n")

  "// AUTO-GENERATED - shared types for SQL queries\n"
  <> "// Do not edit manually\n\n"
  <> "import gleam/option.{type Option}\n\n"
  <> types
}

// Single-file generation (backward compatibility)

pub fn generate_sql_module(
  queries: List(ParsedQuery),
  backend: DbBackend,
  output_path: String,
) -> Result(Nil, String) {
  let content = case backend {
    D1 -> generate_d1_module(queries, False, "")
    Turso -> generate_turso_module(queries, False, "")
    Both -> generate_d1_module(queries, False, "")
  }
  write_file(output_path, content)
}

fn generate_d1_module(
  queries: List(ParsedQuery),
  use_shared_types: Bool,
  package_name: String,
) -> String {
  let queries_with_returns = list.filter(queries, fn(q) { q.returns != [] })
  let shared_import = case use_shared_types {
    True -> {
      let module_path =
        string.replace(package_name, "-", "_") <> ".gen.sql_shared"
      let type_names =
        list.map(queries_with_returns, fn(q) {
          snake_to_pascal(q.name) <> "Row"
        })
        |> string.join(", ")
      case type_names {
        "" -> ""
        _ -> "\nimport " <> module_path <> ".{type " <> type_names <> "}"
      }
    }
    False -> ""
  }

  let imports =
    "import gleam/dynamic/decode\nimport gleam/javascript/promise\nimport gleam/option.{type Option, None, Some}\nimport gflare/d1\nimport gflare/error.{type Error}"
    <> shared_import

  let types = case use_shared_types {
    True -> ""
    False -> list.map(queries, generate_row_type) |> string.join("\n\n")
  }

  let functions = list.map(queries, generate_d1_function) |> string.join("\n\n")

  case types {
    "" -> [imports, "", functions] |> string.join("\n")
    _ -> [imports, "", types, "", functions] |> string.join("\n")
  }
}

fn generate_turso_module(
  queries: List(ParsedQuery),
  use_shared_types: Bool,
  package_name: String,
) -> String {
  let queries_with_returns = list.filter(queries, fn(q) { q.returns != [] })
  let shared_import = case use_shared_types {
    True -> {
      let module_path =
        string.replace(package_name, "-", "_") <> ".gen.sql_shared"
      let type_names =
        list.map(queries_with_returns, fn(q) {
          snake_to_pascal(q.name) <> "Row"
        })
        |> string.join(", ")
      case type_names {
        "" -> ""
        _ -> "\nimport " <> module_path <> ".{type " <> type_names <> "}"
      }
    }
    False -> ""
  }

  let imports =
    "import gleam/javascript/promise\nimport gleam/list\nimport gleam/option.{type Option, None, Some}\nimport gleam/result\nimport gflare/turso\nimport gflare/turso/error.{type TursoError}\nimport gflare/turso/types.{type Value}"
    <> shared_import

  let types = case use_shared_types {
    True -> ""
    False -> list.map(queries, generate_row_type) |> string.join("\n\n")
  }

  let functions =
    list.map(queries, generate_turso_function) |> string.join("\n\n")

  let helper =
    "\n\nfn extract_turso_value(values: List(Value), index: Int, extractor: fn(Value) -> a) -> Result(a, TursoError) {\n  case list.at(values, index) {\n    Ok(value) -> Ok(extractor(value))\n    Error(_) -> Error(error.DecodeError(\"Missing value at index \" <> int.to_string(index)))\n  }\n}"

  case types {
    "" -> [imports, "", functions, helper] |> string.join("\n")
    _ -> [imports, "", types, "", functions, helper] |> string.join("\n")
  }
}

fn generate_row_type(query: ParsedQuery) -> String {
  case query.returns {
    [] -> ""
    fields -> {
      let type_name = snake_to_pascal(query.name) <> "Row"
      let field_strs =
        list.map(fields, fn(f) {
          "  " <> f.name <> ": " <> gleam_type_to_string(f.gleam_type)
        })
        |> string.join(",\n")
      "pub type "
      <> type_name
      <> " {\n"
      <> type_name
      <> "(\n"
      <> field_strs
      <> ",\n)\n}"
    }
  }
}

fn generate_d1_function(query: ParsedQuery) -> String {
  let fn_name = query.name
  let params_type = "d1.Database"
  let param_args =
    list.map(query.params, fn(p) {
      p.name <> ": " <> gleam_type_to_string(p.gleam_type)
    })
    |> list.prepend("db: " <> params_type)
    |> string.join(", ")

  let bind_values =
    list.map(query.params, fn(p) {
      "        " <> gleam_type_to_d1_bind(p.gleam_type) <> "(" <> p.name <> ")"
    })
    |> string.join(",\n")

  let decoder_lines = generate_decoder_lines(query.returns, 0)
  let return_type = case query.returns {
    [] -> "d1.D1Result"
    _ -> {
      let base = snake_to_pascal(query.name) <> "Row"
      case query.returns_many {
        True -> "List(" <> base <> ")"
        False -> base
      }
    }
  }

  let decoder_block = case query.returns {
    [] -> ""
    _ -> {
      let decoder_fields =
        list.map(query.returns, fn(f) { f.name <> ":" })
        |> string.join(", ")
      let decoder_type = snake_to_pascal(query.name) <> "Row"
      "  let decoder = {\n"
      <> decoder_lines
      <> "\n    decode.success("
      <> decoder_type
      <> "("
      <> decoder_fields
      <> "))\n  }\n"
    }
  }

  let run_call = case query.returns {
    [] ->
      "  d1.prepare(db, \""
      <> escape_sql(query.sql)
      <> "\")\n  |> d1.bind([\n"
      <> bind_values
      <> ",\n  ])\n  |> d1.run()"
    _ ->
      case query.returns_many {
        True ->
          "  use result <- promise.await(d1.prepare(db, \""
          <> escape_sql(query.sql)
          <> "\")\n  |> d1.bind([\n"
          <> bind_values
          <> ",\n  ])\n  |> d1.all())\n  case result {\n    Ok(d1_result) -> {\n      let decoded = list.filter_map(d1_result.results, fn(row) {\n        case decode.run(row, decoder) {\n          Ok(row) -> Ok(row)\n          Error(_) -> Error(Nil)\n        }\n      })\n      promise.resolve(Ok(decoded))\n    }\n    Error(e) -> promise.resolve(Error(e))\n  }"
        False ->
          "  use result <- promise.await(d1.prepare(db, \""
          <> escape_sql(query.sql)
          <> "\")\n  |> d1.bind([\n"
          <> bind_values
          <> ",\n  ])\n  |> d1.first())\n  case result {\n    Ok(Some(row)) -> {\n      case decode.run(row, decoder) {\n        Ok(decoded) -> promise.resolve(Ok(decoded))\n        Error(_) -> promise.resolve(Error(error.D1Error(\"Failed to decode row\")))\n      }\n    }\n    Ok(None) -> promise.resolve(Error(error.D1Error(\"No row found\")))\n    Error(e) -> promise.resolve(Error(e))\n  }"
      }
  }

  let return_sig = case query.returns {
    [] -> "promise.Promise(Result(d1.D1Result, Error))"
    _ -> "promise.Promise(Result(" <> return_type <> ", Error))"
  }

  "pub fn "
  <> fn_name
  <> "("
  <> param_args
  <> ") -> "
  <> return_sig
  <> " {\n"
  <> decoder_block
  <> run_call
  <> "\n}"
}

fn generate_turso_function(query: ParsedQuery) -> String {
  let fn_name = query.name
  let params_type = "turso.Config"
  let param_args =
    list.map(query.params, fn(p) {
      p.name <> ": " <> gleam_type_to_string(p.gleam_type)
    })
    |> list.prepend("config: " <> params_type)
    |> string.join(", ")

  let turso_args =
    list.map(query.params, fn(p) {
      "    " <> gleam_type_to_turso_value(p.gleam_type) <> "(" <> p.name <> ")"
    })
    |> string.join(",\n")

  let return_type = case query.returns {
    [] -> "turso.ExecuteResult"
    _ -> {
      let base = snake_to_pascal(query.name) <> "Row"
      case query.returns_many {
        True -> "List(" <> base <> ")"
        False -> base
      }
    }
  }

  let extract_block = case query.returns {
    [] -> ""
    _ -> {
      let extract_lines =
        list.index_map(query.returns, fn(f, index) {
          "      "
          <> f.name
          <> " <- extract_turso_value(row.values, "
          <> int.to_string(index)
          <> ", "
          <> types.gleam_type_to_turso_extractor(f.gleam_type)
          <> ")"
        })
        |> string.join("\n")
      let row_type = snake_to_pascal(query.name) <> "Row"
      let row_expr =
        row_type
        <> "("
        <> list.map(query.returns, fn(f) { f.name <> ":" })
        |> string.join(", ")
        <> ")"
      case query.returns_many {
        True ->
          "  let decoded = list.filter_map(execute_result.rows, fn(row) {\n"
          <> extract_lines
          <> "\n    Ok("
          <> row_expr
          <> ")\n  })\n"
          <> "  promise.resolve(Ok(decoded))"
        False ->
          "  use row <- result.try(execute_result.rows |> list.first |> result.replace_error(error.DecodeError(\"No row found\")))\n"
          <> extract_lines
          <> "\n  promise.resolve(Ok("
          <> row_expr
          <> "))"
      }
    }
  }

  let execute_call = case query.returns {
    [] ->
      "  turso.execute(config, \""
      <> escape_sql(query.sql)
      <> "\", [\n"
      <> turso_args
      <> ",\n  ])"
    _ ->
      "  use result <- promise.await(turso.execute(config, \""
      <> escape_sql(query.sql)
      <> "\", [\n"
      <> turso_args
      <> ",\n  ]))\n  case result {\n    Ok(execute_result) -> {\n"
      <> extract_block
      <> "\n    }\n    Error(e) -> promise.resolve(Error(e))\n  }"
  }

  let return_sig = case query.returns {
    [] -> "promise.Promise(Result(turso.ExecuteResult, TursoError))"
    _ -> "promise.Promise(Result(" <> return_type <> ", TursoError))"
  }

  "pub fn "
  <> fn_name
  <> "("
  <> param_args
  <> ") -> "
  <> return_sig
  <> " {\n"
  <> execute_call
  <> "\n}"
}

fn generate_decoder_lines(result_set: List(ResultSet), index: Int) -> String {
  case result_set {
    [] -> ""
    [field, ..rest] -> {
      let decoder_fn = gleam_type_to_decoder(field.gleam_type)
      let line =
        "    use "
        <> field.name
        <> " <- decode.field("
        <> int.to_string(index)
        <> ", "
        <> decoder_fn
        <> ")"
      let rest_lines = generate_decoder_lines(rest, index + 1)
      case rest_lines {
        "" -> line
        _ -> line <> "\n" <> rest_lines
      }
    }
  }
}

fn snake_to_pascal(s: String) -> String {
  s
  |> string.split("_")
  |> list.map(fn(part) {
    let chars = string.to_graphemes(part)
    case chars {
      [first, ..rest] -> string.uppercase(first) <> string.join(rest, "")
      [] -> ""
    }
  })
  |> string.join("")
}

fn escape_sql(sql: String) -> String {
  sql
  |> string.replace("\\", "\\\\")
  |> string.replace("\"", "\\\"")
  |> string.replace("\n", "\\n")
  |> string.replace("\r", "\\r")
  |> string.replace("\t", "\\t")
}
