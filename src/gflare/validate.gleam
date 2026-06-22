import gflare/request.{type HttpRequest}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/int
import gleam/javascript/promise.{type Promise}
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

pub type Schema(a) {
  Schema(
    decode: fn(Dynamic) -> Result(a, List(ValidationError)),
    field_name: String,
  )
}

pub type ValidationError {
  ValidationError(field: String, message: String)
}

// Basic type schemas

/// Create a string schema for the given field.
pub fn string(field: String) -> Schema(String) {
  Schema(
    decode: fn(data) {
      case decode.run(data, decode.string) {
        Ok(value) -> Ok(value)
        Error(_) -> Error([ValidationError(field, "Expected a string")])
      }
    },
    field_name: field,
  )
}

/// Create an integer schema for the given field.
pub fn int(field: String) -> Schema(Int) {
  Schema(
    decode: fn(data) {
      case decode.run(data, decode.int) {
        Ok(value) -> Ok(value)
        Error(_) -> Error([ValidationError(field, "Expected an integer")])
      }
    },
    field_name: field,
  )
}

pub fn float(field: String) -> Schema(Float) {
  Schema(
    decode: fn(data) {
      case decode.run(data, decode.float) {
        Ok(value) -> Ok(value)
        Error(_) -> Error([ValidationError(field, "Expected a float")])
      }
    },
    field_name: field,
  )
}

pub fn bool(field: String) -> Schema(Bool) {
  Schema(
    decode: fn(data) {
      case decode.run(data, decode.bool) {
        Ok(value) -> Ok(value)
        Error(_) -> Error([ValidationError(field, "Expected a boolean")])
      }
    },
    field_name: field,
  )
}

// Container schemas

pub fn required(field: String, schema: Schema(a)) -> Schema(a) {
  Schema(
    decode: fn(data) {
      case dynamic.classify(data) {
        "Nil" -> Error([ValidationError(field, "Field is required")])
        _ -> schema.decode(data)
      }
    },
    field_name: field,
  )
}

pub fn optional(field: String, schema: Schema(a)) -> Schema(Option(a)) {
  Schema(
    decode: fn(data) {
      case dynamic.classify(data) {
        "Nil" -> Ok(None)
        _ -> {
          case schema.decode(data) {
            Ok(value) -> Ok(Some(value))
            Error(errors) -> Error(errors)
          }
        }
      }
    },
    field_name: field,
  )
}

// String validators

pub fn min_length(schema: Schema(String), length: Int) -> Schema(String) {
  let field = schema.field_name
  Schema(
    decode: fn(data) {
      case schema.decode(data) {
        Ok(value) -> {
          case string.length(value) >= length {
            True -> Ok(value)
            False ->
              Error([
                ValidationError(
                  field,
                  "Must be at least " <> int.to_string(length) <> " characters",
                ),
              ])
          }
        }
        Error(errors) -> Error(errors)
      }
    },
    field_name: field,
  )
}

pub fn max_length(schema: Schema(String), length: Int) -> Schema(String) {
  let field = schema.field_name
  Schema(
    decode: fn(data) {
      case schema.decode(data) {
        Ok(value) -> {
          case string.length(value) <= length {
            True -> Ok(value)
            False ->
              Error([
                ValidationError(
                  field,
                  "Must be at most " <> int.to_string(length) <> " characters",
                ),
              ])
          }
        }
        Error(errors) -> Error(errors)
      }
    },
    field_name: field,
  )
}

pub fn pattern(schema: Schema(String), pattern_str: String) -> Schema(String) {
  let field = schema.field_name
  Schema(
    decode: fn(data) {
      case schema.decode(data) {
        Ok(value) -> {
          case matches_pattern(value, pattern_str) {
            True -> Ok(value)
            False -> Error([ValidationError(field, "Invalid format")])
          }
        }
        Error(errors) -> Error(errors)
      }
    },
    field_name: field,
  )
}

// Number validators

pub fn min(schema: Schema(Int), min_val: Int) -> Schema(Int) {
  let field = schema.field_name
  Schema(
    decode: fn(data) {
      case schema.decode(data) {
        Ok(n) -> {
          case n >= min_val {
            True -> Ok(n)
            False ->
              Error([
                ValidationError(
                  field,
                  "Must be at least " <> int.to_string(min_val),
                ),
              ])
          }
        }
        Error(errors) -> Error(errors)
      }
    },
    field_name: field,
  )
}

pub fn max(schema: Schema(Int), max_val: Int) -> Schema(Int) {
  let field = schema.field_name
  Schema(
    decode: fn(data) {
      case schema.decode(data) {
        Ok(n) -> {
          case n <= max_val {
            True -> Ok(n)
            False ->
              Error([
                ValidationError(
                  field,
                  "Must be at most " <> int.to_string(max_val),
                ),
              ])
          }
        }
        Error(errors) -> Error(errors)
      }
    },
    field_name: field,
  )
}

pub fn between(schema: Schema(Int), min_val: Int, max_val: Int) -> Schema(Int) {
  let field = schema.field_name
  Schema(
    decode: fn(data) {
      case schema.decode(data) {
        Ok(n) -> {
          case n >= min_val && n <= max_val {
            True -> Ok(n)
            False ->
              Error([
                ValidationError(
                  field,
                  "Must be between "
                    <> int.to_string(min_val)
                    <> " and "
                    <> int.to_string(max_val),
                ),
              ])
          }
        }
        Error(errors) -> Error(errors)
      }
    },
    field_name: field,
  )
}

pub fn positive(schema: Schema(Int)) -> Schema(Int) {
  min(schema, 1)
}

pub fn negative(schema: Schema(Int)) -> Schema(Int) {
  let field = schema.field_name
  Schema(
    decode: fn(data) {
      case schema.decode(data) {
        Ok(n) -> {
          case n < 0 {
            True -> Ok(n)
            False -> Error([ValidationError(field, "Must be negative")])
          }
        }
        Error(errors) -> Error(errors)
      }
    },
    field_name: field,
  )
}

// Common validation helpers

pub fn email(field: String) -> Schema(String) {
  string(field)
  |> pattern("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$")
}

pub fn url(field: String) -> Schema(String) {
  string(field) |> pattern("^https?://[^\\s/$.?#].[^\\s]*$")
}

pub fn uuid(field: String) -> Schema(String) {
  string(field)
  |> pattern("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")
}

pub fn ulid(field: String) -> Schema(String) {
  string(field) |> pattern("^[0-9A-HJKMNP-TV-Z]{26}$")
}

pub fn date(field: String) -> Schema(String) {
  string(field) |> pattern("^\\d{4}-\\d{2}-\\d{2}$")
}

pub fn time(field: String) -> Schema(String) {
  string(field) |> pattern("^\\d{2}:\\d{2}:\\d{2}$")
}

pub fn datetime(field: String) -> Schema(String) {
  string(field) |> pattern("^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}")
}

pub fn one_of(field: String, values: List(String)) -> Schema(String) {
  Schema(
    decode: fn(data) {
      case decode.run(data, decode.string) {
        Ok(value) -> {
          case list.contains(values, value) {
            True -> Ok(value)
            False ->
              Error([
                ValidationError(
                  field,
                  "Must be one of: " <> string.join(values, ", "),
                ),
              ])
          }
        }
        Error(_) -> Error([ValidationError(field, "Expected a string")])
      }
    },
    field_name: field,
  )
}

// Custom validators

pub fn custom(
  schema: Schema(a),
  validator: fn(a) -> Result(a, String),
) -> Schema(a) {
  let field = schema.field_name
  Schema(
    decode: fn(data) {
      case schema.decode(data) {
        Ok(value) -> {
          case validator(value) {
            Ok(valid) -> Ok(valid)
            Error(msg) -> Error([ValidationError(field, msg)])
          }
        }
        Error(errors) -> Error(errors)
      }
    },
    field_name: field,
  )
}

// Validation functions

/// Validate data against a schema. Returns Ok(value) or Error(list of validation errors).
pub fn validate(
  schema: Schema(a),
  data: Dynamic,
) -> Result(a, List(ValidationError)) {
  schema.decode(data)
}

/// Validate request body against a schema. Returns Ok(value) or Error(list of validation errors).
pub fn validate_body(
  schema: Schema(a),
  request: HttpRequest,
) -> Promise(Result(a, List(ValidationError))) {
  use body <- promise.await(request.json(request))
  case body {
    Ok(data) -> promise.resolve(validate(schema, data))
    Error(_) ->
      promise.resolve(Error([ValidationError("body", "Invalid JSON")]))
  }
}

// Error formatting

/// Format validation errors as JSON for API responses.
pub fn format_errors(errors: List(ValidationError)) -> json.Json {
  json.array(errors, fn(e) {
    json.object([
      #("field", json.string(e.field)),
      #("message", json.string(e.message)),
    ])
  })
}

pub fn errors_to_string(errors: List(ValidationError)) -> String {
  let error_strings = list.map(errors, fn(e) { e.field <> ": " <> e.message })
  string.join(error_strings, "; ")
}

// Internal helpers

fn matches_pattern(value: String, pattern_str: String) -> Bool {
  do_matches_pattern(value, pattern_str)
}

@external(javascript, "../gflare_ffi_validate.mjs", "matches_pattern")
fn do_matches_pattern(value: String, pattern: String) -> Bool
