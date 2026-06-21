import gleeunit
import gleeunit/should

import gleam/list
import gleam/option.{None, Some}
import gflare/turso
import gflare/turso/types
import gflare/turso/cloud

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

// Value type tests

pub fn value_text_equality_test() {
  turso.text("a") |> should.equal(turso.text("a"))
  turso.text("a") |> should.not_equal(turso.text("b"))
}

pub fn value_int_equality_test() {
  turso.int(1) |> should.equal(turso.int(1))
  turso.int(1) |> should.not_equal(turso.int(2))
}

pub fn value_null_equality_test() {
  turso.null_value() |> should.equal(turso.null_value())
}

// ExecuteResult tests

pub fn execute_result_empty_test() {
  let result =
    types.ExecuteResult(rows: [], columns: [], rows_affected: 0, last_insert_rowid: None)
  result.rows |> should.equal([])
  result.columns |> should.equal([])
  result.rows_affected |> should.equal(0)
  result.last_insert_rowid |> should.equal(None)
}

pub fn execute_result_with_rows_test() {
  let row =
    types.Row(
      columns: ["id", "name"],
      values: [types.Integer(1), types.Text("Alice")],
    )
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

// Row tests

pub fn row_construction_test() {
  let row =
    types.Row(
      columns: ["id", "name"],
      values: [types.Integer(1), types.Text("Alice")],
    )
  row.columns |> should.equal(["id", "name"])
  list.length(row.values) |> should.equal(2)
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
    types.Row(
      columns: ["id", "name", "score", "data", "flag"],
      values: [
        types.Integer(1),
        types.Text("Alice"),
        types.Float(9.5),
        types.Blob(<<1, 2>>),
        types.Null,
      ],
    )
  list.length(row.values) |> should.equal(5)
}

pub fn empty_row_test() {
  let row = types.Row(columns: [], values: [])
  row.columns |> should.equal([])
  row.values |> should.equal([])
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
  let db = cloud.Database(
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
