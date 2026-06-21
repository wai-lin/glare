import gleeunit
import gleeunit/should

import gleam/io
import gleam/list
import gleam/string
import gflare/cli/db/generate
import gflare/cli/db/parse_sql
import gflare/cli/db/types.{D1, GBool, GFloat, GInt, GOption, GString, ParsedQuery, QueryParam, ResultSet, Turso}

pub fn main() {
  gleeunit.main()
}

// Type parsing tests

pub fn parse_gleam_type_int_test() {
  types.parse_gleam_type("Int") |> should.equal(GInt)
}

pub fn parse_gleam_type_float_test() {
  types.parse_gleam_type("Float") |> should.equal(GFloat)
}

pub fn parse_gleam_type_string_test() {
  types.parse_gleam_type("String") |> should.equal(GString)
}

pub fn parse_gleam_type_bool_test() {
  types.parse_gleam_type("Bool") |> should.equal(GBool)
}

pub fn parse_gleam_type_option_int_test() {
  types.parse_gleam_type("Option(Int)") |> should.equal(GOption(GInt))
}

pub fn parse_gleam_type_option_string_test() {
  types.parse_gleam_type("Option(String)") |> should.equal(GOption(GString))
}

pub fn parse_gleam_type_unknown_test() {
  types.parse_gleam_type("Unknown") |> should.equal(GString)
}

// Type to string tests

pub fn gleam_type_to_string_int_test() {
  types.gleam_type_to_string(GInt) |> should.equal("Int")
}

pub fn gleam_type_to_string_float_test() {
  types.gleam_type_to_string(GFloat) |> should.equal("Float")
}

pub fn gleam_type_to_string_string_test() {
  types.gleam_type_to_string(GString) |> should.equal("String")
}

pub fn gleam_type_to_string_bool_test() {
  types.gleam_type_to_string(GBool) |> should.equal("Bool")
}

pub fn gleam_type_to_string_option_test() {
  types.gleam_type_to_string(GOption(GInt)) |> should.equal("Option(Int)")
}

// Type to decoder tests

pub fn gleam_type_to_decoder_int_test() {
  types.gleam_type_to_decoder(GInt) |> should.equal("decode.int")
}

pub fn gleam_type_to_decoder_float_test() {
  types.gleam_type_to_decoder(GFloat) |> should.equal("decode.float")
}

pub fn gleam_type_to_decoder_string_test() {
  types.gleam_type_to_decoder(GString) |> should.equal("decode.string")
}

pub fn gleam_type_to_decoder_option_test() {
  types.gleam_type_to_decoder(GOption(GString)) |> should.equal("decode.optional(decode.string)")
}

// Type to D1 bind tests

pub fn gleam_type_to_d1_bind_int_test() {
  types.gleam_type_to_d1_bind(GInt) |> should.equal("d1.int")
}

pub fn gleam_type_to_d1_bind_string_test() {
  types.gleam_type_to_d1_bind(GString) |> should.equal("d1.text")
}

pub fn gleam_type_to_d1_bind_option_test() {
  types.gleam_type_to_d1_bind(GOption(GInt)) |> should.equal("d1.null_value")
}

// Type to Turso value tests

pub fn gleam_type_to_turso_value_int_test() {
  types.gleam_type_to_turso_value(GInt) |> should.equal("turso.int")
}

pub fn gleam_type_to_turso_value_string_test() {
  types.gleam_type_to_turso_value(GString) |> should.equal("turso.text")
}

pub fn gleam_type_to_turso_value_option_test() {
  types.gleam_type_to_turso_value(GOption(GInt)) |> should.equal("turso.null_value")
}

// SQL parsing tests - these test the parse_sql_content function indirectly

pub fn parse_simple_select_test() {
  let sql = "-- params: user_id: Int\n-- returns: id: Int, name: String\nSELECT id, name FROM users WHERE id = ?1"
  case parse_sql.parse_file_content(sql) {
    Ok(query) -> {
      query.name |> should.equal("")
      list.length(query.params) |> should.equal(1)
      list.length(query.returns) |> should.equal(2)
      string.contains(query.sql, "SELECT id, name FROM users") |> should.be_true()
    }
    Error(e) -> {
      io.println(e.message)
      should.fail()
    }
  }
}

pub fn parse_insert_test() {
  let sql = "-- params: name: String, email: String\nINSERT INTO users (name, email) VALUES (?1, ?2)"
  case parse_sql.parse_file_content(sql) {
    Ok(query) -> {
      query.name |> should.equal("")
      list.length(query.params) |> should.equal(2)
      list.length(query.returns) |> should.equal(0)
      string.contains(query.sql, "INSERT INTO users") |> should.be_true()
    }
    Error(e) -> {
      io.println(e.message)
      should.fail()
    }
  }
}

pub fn parse_with_options_test() {
  let sql = "-- params: user_id: Int\n-- returns: id: Int, name: String, email: Option(String)\nSELECT id, name, email FROM users WHERE id = ?1"
  case parse_sql.parse_file_content(sql) {
    Ok(query) -> {
      list.length(query.returns) |> should.equal(3)
      case query.returns {
        [_, _, email_field] -> email_field.gleam_type |> should.equal(GOption(GString))
        _ -> should.fail()
      }
    }
    Error(e) -> {
      io.println(e.message)
      should.fail()
    }
  }
}

pub fn parse_no_annotations_test() {
  let sql = "SELECT * FROM users"
  case parse_sql.parse_file_content(sql) {
    Ok(query) -> {
      list.length(query.params) |> should.equal(0)
      list.length(query.returns) |> should.equal(0)
      string.contains(query.sql, "SELECT * FROM users") |> should.be_true()
    }
    Error(e) -> {
      io.println(e.message)
      should.fail()
    }
  }
}

pub fn parse_empty_sql_test() {
  let sql = "-- just a comment\n"
  case parse_sql.parse_file_content(sql) {
    Ok(_) -> should.fail()
    Error(_) -> Nil
  }
}

pub fn parse_multiline_query_test() {
  let sql = "-- params: user_id: Int\n-- returns: id: Int, name: String\nSELECT\n  id,\n  name\nFROM users\nWHERE id = ?1"
  case parse_sql.parse_file_content(sql) {
    Ok(query) -> {
      string.contains(query.sql, "SELECT") |> should.be_true()
      string.contains(query.sql, "FROM users") |> should.be_true()
    }
    Error(e) -> {
      io.println(e.message)
      should.fail()
    }
  }
}

// Code generation tests

pub fn generate_d1_module_test() {
  let queries = [
    ParsedQuery(
      name: "find_user",
      params: [QueryParam(name: "user_id", gleam_type: GInt)],
      returns: [
        ResultSet(name: "id", gleam_type: GInt),
        ResultSet(name: "name", gleam_type: GString),
      ],
      sql: "SELECT id, name FROM users WHERE id = ?1",
    ),
  ]
  case generate.generate_sql_module(queries, D1, "/tmp/test_sql.gleam") {
    Ok(Nil) -> Nil
    Error(e) -> {
      io.println(e)
      should.fail()
    }
  }
}

pub fn generate_turso_module_test() {
  let queries = [
    ParsedQuery(
      name: "find_user",
      params: [QueryParam(name: "user_id", gleam_type: GInt)],
      returns: [
        ResultSet(name: "id", gleam_type: GInt),
        ResultSet(name: "name", gleam_type: GString),
      ],
      sql: "SELECT id, name FROM users WHERE id = ?1",
    ),
  ]
  case generate.generate_sql_module(queries, Turso, "/tmp/test_sql_turso.gleam") {
    Ok(Nil) -> Nil
    Error(e) -> {
      io.println(e)
      should.fail()
    }
  }
}
