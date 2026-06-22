import gleeunit
import gleeunit/should

import gflare/validate

pub fn main() {
  gleeunit.main()
}

// ValidationError tests

pub fn validation_error_has_correct_fields_test() {
  let error = validate.ValidationError(field: "name", message: "Required")
  error.field |> should.equal("name")
  error.message |> should.equal("Required")
}

// Schema type tests

pub fn string_schema_test() {
  let schema = validate.string("name")
  schema.field_name |> should.equal("name")
}

pub fn int_schema_test() {
  let schema = validate.int("age")
  schema.field_name |> should.equal("age")
}

pub fn float_schema_test() {
  let schema = validate.float("score")
  schema.field_name |> should.equal("score")
}

pub fn bool_schema_test() {
  let schema = validate.bool("active")
  schema.field_name |> should.equal("active")
}

// Common validators tests

pub fn email_schema_test() {
  let schema = validate.email("email")
  schema.field_name |> should.equal("email")
}

pub fn url_schema_test() {
  let schema = validate.url("website")
  schema.field_name |> should.equal("website")
}

pub fn uuid_schema_test() {
  let schema = validate.uuid("id")
  schema.field_name |> should.equal("id")
}

pub fn ulid_schema_test() {
  let schema = validate.ulid("id")
  schema.field_name |> should.equal("id")
}

pub fn date_schema_test() {
  let schema = validate.date("created_at")
  schema.field_name |> should.equal("created_at")
}

pub fn time_schema_test() {
  let schema = validate.time("start_time")
  schema.field_name |> should.equal("start_time")
}

pub fn datetime_schema_test() {
  let schema = validate.datetime("timestamp")
  schema.field_name |> should.equal("timestamp")
}

// Number validator tests

pub fn min_schema_test() {
  let schema = validate.int("age") |> validate.min(0)
  schema.field_name |> should.equal("age")
}

pub fn max_schema_test() {
  let schema = validate.int("age") |> validate.max(150)
  schema.field_name |> should.equal("age")
}

pub fn between_schema_test() {
  let schema = validate.int("age") |> validate.between(0, 150)
  schema.field_name |> should.equal("age")
}

pub fn positive_schema_test() {
  let schema = validate.int("count") |> validate.positive
  schema.field_name |> should.equal("count")
}

pub fn negative_schema_test() {
  let schema = validate.int("debt") |> validate.negative
  schema.field_name |> should.equal("debt")
}

// String validator tests

pub fn min_length_schema_test() {
  let schema = validate.string("name") |> validate.min_length(1)
  schema.field_name |> should.equal("name")
}

pub fn max_length_schema_test() {
  let schema = validate.string("name") |> validate.max_length(100)
  schema.field_name |> should.equal("name")
}

pub fn pattern_schema_test() {
  let schema = validate.string("code") |> validate.pattern("^[A-Z]+$")
  schema.field_name |> should.equal("code")
}

// one_of validator tests

pub fn one_of_schema_test() {
  let schema = validate.one_of("status", ["active", "inactive", "pending"])
  schema.field_name |> should.equal("status")
}

// format_errors tests

pub fn format_errors_creates_json_test() {
  let errors = [
    validate.ValidationError(field: "name", message: "Required"),
    validate.ValidationError(field: "email", message: "Invalid format"),
  ]
  let json = validate.format_errors(errors)
  // Just verify it doesn't crash
  case json {
    _ -> Nil
  }
}

pub fn format_errors_empty_list_test() {
  let errors = []
  let json = validate.format_errors(errors)
  case json {
    _ -> Nil
  }
}

// errors_to_string tests

pub fn errors_to_stringformats_correctly_test() {
  let errors = [
    validate.ValidationError(field: "name", message: "Required"),
    validate.ValidationError(field: "email", message: "Invalid format"),
  ]
  let result = validate.errors_to_string(errors)
  result |> should.equal("name: Required; email: Invalid format")
}

pub fn errors_to_string_single_error_test() {
  let errors = [
    validate.ValidationError(field: "age", message: "Must be positive"),
  ]
  let result = validate.errors_to_string(errors)
  result |> should.equal("age: Must be positive")
}

pub fn errors_to_string_empty_list_test() {
  let errors = []
  let result = validate.errors_to_string(errors)
  result |> should.equal("")
}
