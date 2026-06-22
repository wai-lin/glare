import gleeunit
import gleeunit/should

import gflare/turso
import gflare/turso/cloud
import gflare/turso/error
import gflare/turso/types
import gleam/bit_array
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/string

pub fn main() {
  gleeunit.main()
}

// Config tests

pub fn connect_creates_config_test() {
  let config = turso.connect("lib://my-db.turio.io", "token123")
  config.url |> should.equal("lib://my-db.turio.io")
  config.auth_token |> should.equal("token123")
}

pub fn connect_with_empty_url_test() {
  let config = turso.connect("", "")
  config.url |> should.equal("")
  config.auth_token |> should.equal("")
}

// Value constructor tests

pub fn text_value_test() {
  let val = turso.text("hello")
  case val {
    types.Text(s) -> s |> should.equal("hello")
    _ -> should.fail()
  }
}

pub fn int_value_test() {
  let val = turso.int(42)
  case val {
    types.Integer(i) -> i |> should.equal(42)
    _ -> should.fail()
  }
}

pub fn float_value_test() {
  let val = turso.float(3.14)
  case val {
    types.Float(f) -> f |> should.equal(3.14)
    _ -> should.fail()
  }
}

pub fn blob_value_test() {
  let val = turso.blob(<<1, 2, 3>>)
  case val {
    types.Blob(b) -> b |> should.equal(<<1, 2, 3>>)
    _ -> should.fail()
  }
}

pub fn null_value_test() {
  let val = turso.null_value()
  val |> should.equal(types.Null)
}

pub fn date_value_test() {
  let val = turso.date("2024-01-15")
  case val {
    types.Date(s) -> s |> should.equal("2024-01-15")
    _ -> should.fail()
  }
}

pub fn time_value_test() {
  let val = turso.time("14:30:00")
  case val {
    types.Time(s) -> s |> should.equal("14:30:00")
    _ -> should.fail()
  }
}

pub fn timestamp_value_test() {
  let val = turso.timestamp("2024-01-15T14:30:00Z")
  case val {
    types.Timestamp(s) -> s |> should.equal("2024-01-15T14:30:00Z")
    _ -> should.fail()
  }
}

pub fn uuid_value_test() {
  let val = turso.uuid("550e8400-e29b-41d4-a716-446655440000")
  case val {
    types.Uuid(s) -> s |> should.equal("550e8400-e29b-41d4-a716-446655440000")
    _ -> should.fail()
  }
}

pub fn json_string_value_test() {
  let val = turso.json_string("{\"key\": \"value\"}")
  case val {
    types.JsonString(s) -> s |> should.equal("{\"key\": \"value\"}")
    _ -> should.fail()
  }
}

// Value type tests

pub fn value_text_equality_test() {
  turso.text("a") |> should.equal(turso.text("a"))
  turso.text("a") |> should.not_equal(turso.text("b"))
}

pub fn value_int_equality_test() {
  turso.int(1) |> should.equal(turso.int(1))
  turso.int(1) |> should.not_equal(turso.int(2))
}

pub fn value_float_equality_test() {
  turso.float(1.5) |> should.equal(turso.float(1.5))
  turso.float(1.5) |> should.not_equal(turso.float(2.5))
}

pub fn value_blob_equality_test() {
  turso.blob(<<1, 2>>) |> should.equal(turso.blob(<<1, 2>>))
  turso.blob(<<1, 2>>) |> should.not_equal(turso.blob(<<3, 4>>))
}

pub fn value_null_equality_test() {
  turso.null_value() |> should.equal(turso.null_value())
}

pub fn value_date_equality_test() {
  turso.date("2024-01-01") |> should.equal(turso.date("2024-01-01"))
  turso.date("2024-01-01") |> should.not_equal(turso.date("2024-12-31"))
}

pub fn value_different_types_not_equal_test() {
  turso.text("1") |> should.not_equal(turso.int(1))
  turso.int(0) |> should.not_equal(turso.float(0.0))
  turso.null_value() |> should.not_equal(turso.text("null"))
}

// ExecuteResult tests

pub fn execute_result_empty_test() {
  let result =
    types.ExecuteResult(
      rows: [],
      columns: [],
      rows_affected: 0,
      last_insert_rowid: None,
    )
  result.rows |> should.equal([])
  result.columns |> should.equal([])
  result.rows_affected |> should.equal(0)
  result.last_insert_rowid |> should.equal(None)
}

pub fn execute_result_with_rows_test() {
  let row =
    types.Row(columns: ["id", "name"], values: [
      types.Integer(1),
      types.Text("Alice"),
    ])
  let result =
    types.ExecuteResult(
      rows: [row],
      columns: ["id", "name"],
      rows_affected: 1,
      last_insert_rowid: Some(1),
    )
  list.length(result.rows) |> should.equal(1)
  result.rows_affected |> should.equal(1)
  result.last_insert_rowid |> should.equal(Some(1))
}

pub fn execute_result_multiple_rows_test() {
  let rows = [
    types.Row(columns: ["id"], values: [types.Integer(1)]),
    types.Row(columns: ["id"], values: [types.Integer(2)]),
    types.Row(columns: ["id"], values: [types.Integer(3)]),
  ]
  let result =
    types.ExecuteResult(
      rows:,
      columns: ["id"],
      rows_affected: 3,
      last_insert_rowid: Some(3),
    )
  list.length(result.rows) |> should.equal(3)
  result.rows_affected |> should.equal(3)
}

// Row tests

pub fn row_construction_test() {
  let row =
    types.Row(columns: ["id", "name"], values: [
      types.Integer(1),
      types.Text("Alice"),
    ])
  row.columns |> should.equal(["id", "name"])
  list.length(row.values) |> should.equal(2)
}

pub fn row_single_column_test() {
  let row = types.Row(columns: ["count"], values: [types.Integer(42)])
  row.columns |> should.equal(["count"])
  list.length(row.values) |> should.equal(1)
}

// BatchMode tests

pub fn batch_mode_read_test() {
  types.Read |> should.equal(types.Read)
}

pub fn batch_mode_write_test() {
  types.Write |> should.equal(types.Write)
}

pub fn batch_modes_not_equal_test() {
  types.Read |> should.not_equal(types.Write)
}

// Complex value tests

pub fn mixed_values_in_row_test() {
  let row =
    types.Row(columns: ["id", "name", "score", "data", "flag"], values: [
      types.Integer(1),
      types.Text("Alice"),
      types.Float(9.5),
      types.Blob(<<1, 2>>),
      types.Null,
    ])
  list.length(row.values) |> should.equal(5)
}

pub fn empty_row_test() {
  let row = types.Row(columns: [], values: [])
  row.columns |> should.equal([])
  row.values |> should.equal([])
}

// Turso error tests

pub fn turso_error_api_test() {
  let err = error.ApiError("rate limited")
  error.to_string(err) |> should.equal("Turso API error: rate limited")
}

pub fn turso_error_not_found_test() {
  let err = error.NotFound("my-db")
  error.to_string(err) |> should.equal("Database not found: my-db")
}

pub fn turso_error_conflict_test() {
  let err = error.Conflict("my-db")
  error.to_string(err) |> should.equal("Database already exists: my-db")
}

pub fn turso_error_network_test() {
  let err = error.NetworkError("timeout")
  error.to_string(err) |> should.equal("Network error: timeout")
}

pub fn turso_error_decode_test() {
  let err = error.DecodeError("invalid JSON")
  error.to_string(err) |> should.equal("Decode error: invalid JSON")
}

pub fn turso_error_api_empty_message_test() {
  let err = error.ApiError("")
  error.to_string(err) |> should.equal("Turso API error: ")
}

// Cloud config tests

pub fn cloud_connect_test() {
  let config = cloud.connect("my-org", "token123")
  config.org |> should.equal("my-org")
  config.token |> should.equal("token123")
}

pub fn cloud_connect_empty_test() {
  let config = cloud.connect("", "")
  config.org |> should.equal("")
  config.token |> should.equal("")
}

// Cloud database type tests

pub fn database_construction_test() {
  let db =
    cloud.Database(
      name: "test-db",
      db_id: "abc-123",
      hostname: "test-db-org.turso.io",
      group: "default",
      primary_region: "aws-us-east-1",
    )
  db.name |> should.equal("test-db")
  db.db_id |> should.equal("abc-123")
  db.hostname |> should.equal("test-db-org.turso.io")
  db.group |> should.equal("default")
  db.primary_region |> should.equal("aws-us-east-1")
}

pub fn database_equality_test() {
  let db1 =
    cloud.Database(
      name: "db",
      db_id: "1",
      hostname: "h",
      group: "g",
      primary_region: "r",
    )
  let db2 =
    cloud.Database(
      name: "db",
      db_id: "1",
      hostname: "h",
      group: "g",
      primary_region: "r",
    )
  db1 |> should.equal(db2)
}

// Cloud token type tests

pub fn token_result_test() {
  let token = cloud.TokenResult(jwt: "eyJhbGciOiJIUzI1NiJ9")
  token.jwt |> should.equal("eyJhbGciOiJIUzI1NiJ9")
}

// Cloud group type tests

pub fn group_construction_test() {
  let group = cloud.Group(name: "default", location: "aws-us-east-1")
  group.name |> should.equal("default")
  group.location |> should.equal("aws-us-east-1")
}

pub fn group_equality_test() {
  let g1 = cloud.Group(name: "g", location: "us-east-1")
  let g2 = cloud.Group(name: "g", location: "us-east-1")
  g1 |> should.equal(g2)
}

// Blob encoding edge cases

pub fn blob_empty_test() {
  let val = turso.blob(<<>>)
  case val {
    types.Blob(b) -> bit_array.byte_size(b) |> should.equal(0)
    _ -> should.fail()
  }
}

pub fn blob_large_test() {
  let data =
    bit_array.base64_decode("AQIDBAUGBwgJCgsMDQ4PEBESExQVFhcYGRobHB0eHyA=")
    |> should.be_ok
  let val = turso.blob(data)
  case val {
    types.Blob(b) -> bit_array.byte_size(b) |> should.equal(32)
    _ -> should.fail()
  }
}

// Value JSON encoding round-trip

pub fn text_value_json_encoding_test() {
  let val = turso.text("hello")
  let encoded =
    json.to_string(json.object([#("value", encode_value_json(val))]))
  string.contains(encoded, "hello") |> should.be_true()
}

pub fn int_value_json_encoding_test() {
  let val = turso.int(42)
  let encoded =
    json.to_string(json.object([#("value", encode_value_json(val))]))
  string.contains(encoded, "42") |> should.be_true()
}

fn encode_value_json(val: types.Value) -> json.Json {
  case val {
    types.Text(s) -> json.string(s)
    types.Integer(i) -> json.int(i)
    types.Float(f) -> json.float(f)
    types.Blob(_) -> json.string("blob")
    types.Null -> json.null()
    types.Date(s) -> json.string(s)
    types.Time(s) -> json.string(s)
    types.Timestamp(s) -> json.string(s)
    types.Uuid(s) -> json.string(s)
    types.JsonString(s) -> json.string(s)
  }
}
