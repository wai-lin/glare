import gflare/cli/db/types.{
  type DbBackend, type ParsedQuery, type ResultSet, D1, Turso,
  gleam_type_to_d1_bind, gleam_type_to_decoder, gleam_type_to_string, gleam_type_to_turso_value,
}
import gleam/list
import gleam/string
import simplifile

pub fn generate_sql_module(
  queries: List(ParsedQuery),
  backend: DbBackend,
  output_path: String,
) -> Result(Nil, String) {
  let content = case backend {
    D1 -> generate_d1_module(queries)
    Turso -> generate_turso_module(queries)
  }
  case simplifile.write(to: output_path, contents: content) {
    Ok(Nil) -> Ok(Nil)
    Error(e) -> Error("Failed to write " <> output_path <> ": " <> simplifile.describe_error(e))
  }
}

fn generate_d1_module(queries: List(ParsedQuery)) -> String {
  let imports =
    "import gleam/dynamic/decode\nimport gleam/javascript/promise\nimport gleam/option.{type Option, None, Some}\nimport gflare/d1\nimport gflare/error.{type Error}"

  let types = list.map(queries, generate_d1_row_type) |> string.join("\n\n")

  let functions =
    list.map(queries, generate_d1_function) |> string.join("\n\n")

  [imports, "", types, "", functions] |> string.join("\n")
}

fn generate_turso_module(queries: List(ParsedQuery)) -> String {
  let imports =
    "import gleam/dynamic/decode\nimport gleam/javascript/promise\nimport gleam/option.{type Option, None, Some}\nimport gflare/turso\nimport gflare/turso/error.{type TursoError}"

  let types = list.map(queries, generate_turso_row_type) |> string.join("\n\n")

  let functions =
    list.map(queries, generate_turso_function) |> string.join("\n\n")

  [imports, "", types, "", functions] |> string.join("\n")
}

fn generate_d1_row_type(query: ParsedQuery) -> String {
  case query.returns {
    [] -> ""
    fields -> {
      let type_name = snake_to_pascal(query.name) <> "Row"
      let field_strs =
        list.map(fields, fn(f) {
          "  " <> f.name <> ": " <> gleam_type_to_string(f.gleam_type)
        })
        |> string.join(",\n")
      "pub type " <> type_name <> " {\n" <> type_name <> "(\n" <> field_strs <> ",\n)\n}"
    }
  }
}

fn generate_turso_row_type(query: ParsedQuery) -> String {
  generate_d1_row_type(query)
}

fn generate_d1_function(query: ParsedQuery) -> String {
  let fn_name = query.name
  let params_type = "d1.Database"
  let param_args =
    list.map(query.params, fn(p) {
      p.name <> ": " <> gleam_type_to_string(p.gleam_type)
    })
    |> list.prepend(params_type <> " db")
    |> string.join(", ")

  let bind_values =
    list.map(query.params, fn(p) {
      "        " <> gleam_type_to_d1_bind(p.gleam_type) <> "(" <> p.name <> ")"
    })
    |> string.join(",\n")

  let decoder_lines = generate_decoder_lines(query.returns, 0)
  let return_type = case query.returns {
    [] -> "d1.D1Result"
    _ -> snake_to_pascal(query.name) <> "Row"
  }

  let decoder_block = case query.returns {
    [] -> ""
    _ -> {
      let decoder_fields =
        list.map(query.returns, fn(f) {
          "    " <> f.name
        })
        |> string.join("\n")
      "  let decoder = {\n" <> decoder_lines <> "\n    decode.success(" <> return_type <> "(" <> decoder_fields <> ":))\n  }\n"
    }
  }

  let run_call = case query.returns {
    [] ->
      "  d1.prepare(db, \"" <> escape_sql(query.sql) <> "\")\n  |> d1.bind([\n" <> bind_values <> ",\n  ])\n  |> d1.run()"
    _ ->
      "  use result <- promise.await(d1.prepare(db, \"" <> escape_sql(query.sql) <> "\")\n  |> d1.bind([\n" <> bind_values <> ",\n  ])\n  |> d1.first())\n  case result {\n    Ok(Some(row)) -> {\n      case decode.run(row, decoder) {\n        Ok(decoded) -> promise.resolve(Ok(decoded))\n        Error(_) -> promise.resolve(Error(error.D1Error(\"Failed to decode row\")))\n      }\n    }\n    Ok(None) -> promise.resolve(Error(error.D1Error(\"No row found\")))\n    Error(e) -> promise.resolve(Error(e))\n  }"
  }

  let return_sig = case query.returns {
    [] -> "promise.Promise(Result(d1.D1Result, Error))"
    _ -> "promise.Promise(Result(" <> return_type <> ", Error))"
  }

  "pub fn " <> fn_name <> "(" <> param_args <> ") -> " <> return_sig <> " {\n" <> decoder_block <> run_call <> "\n}"
}

fn generate_turso_function(query: ParsedQuery) -> String {
  let fn_name = query.name
  let params_type = "turso.Config"
  let param_args =
    list.map(query.params, fn(p) {
      p.name <> ": " <> gleam_type_to_string(p.gleam_type)
    })
    |> list.prepend(params_type <> " config")
    |> string.join(", ")

  let turso_args =
    list.map(query.params, fn(p) {
      "    " <> gleam_type_to_turso_value(p.gleam_type) <> "(" <> p.name <> ")"
    })
    |> string.join(",\n")

  let decoder_lines = generate_decoder_lines(query.returns, 0)
  let return_type = case query.returns {
    [] -> "turso.ExecuteResult"
    _ -> snake_to_pascal(query.name) <> "Row"
  }

  let decoder_block = case query.returns {
    [] -> ""
    _ -> {
      let decoder_fields =
        list.map(query.returns, fn(f) {
          "    " <> f.name
        })
        |> string.join("\n")
      "  let decoder = {\n" <> decoder_lines <> "\n    decode.success(" <> return_type <> "(" <> decoder_fields <> ":))\n  }\n"
    }
  }

  let execute_call = case query.returns {
    [] ->
      "  turso.execute(config, \"" <> escape_sql(query.sql) <> "\", [\n" <> turso_args <> ",\n  ])"
    _ ->
      "  use result <- promise.await(turso.execute(config, \"" <> escape_sql(query.sql) <> "\", [\n" <> turso_args <> ",\n  ]))\n  case result {\n    Ok(execute_result) -> {\n      case execute_result.rows {\n        [row, ..] -> {\n          case decode.run(row.values, decoder) {\n            Ok(decoded) -> promise.resolve(Ok(decoded))\n            Error(_) -> promise.resolve(Error(error.DecodeError(\"Failed to decode row\")))\n          }\n        }\n        [] -> promise.resolve(Error(error.NotFound(\"No row found\")))\n      }\n    }\n    Error(e) -> promise.resolve(Error(e))\n  }"
  }

  let return_sig = case query.returns {
    [] -> "promise.Promise(Result(turso.ExecuteResult, TursoError))"
    _ -> "promise.Promise(Result(" <> return_type <> ", TursoError))"
  }

  "pub fn " <> fn_name <> "(" <> param_args <> ") -> " <> return_sig <> " {\n" <> decoder_block <> execute_call <> "\n}"
}

fn generate_decoder_lines(result_set: List(ResultSet), index: Int) -> String {
  case result_set {
    [] -> ""
    [field, ..rest] -> {
      let decoder_fn = gleam_type_to_decoder(field.gleam_type)
      let line = "    use " <> field.name <> " <- decode.field(" <> int_to_string(index) <> ", " <> decoder_fn <> ")"
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
    case string.starts_with(part, "") {
      True -> {
        let chars = string.to_graphemes(part)
        case chars {
          [first, ..rest] ->
            string.uppercase(first) <> string.join(rest, "")
          [] -> ""
        }
      }
      False -> ""
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

fn int_to_string(n: Int) -> String {
  case n {
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
    _ -> {
      let digit = n % 10
      let rest = n / 10
      int_to_string(rest) <> int_to_string(digit)
    }
  }
}
