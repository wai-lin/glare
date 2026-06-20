import gleeunit
import gleeunit/should

import gleam/json
import gleam/option.{None, Some}
import glare/json_util

pub fn main() {
  gleeunit.main()
}

// sparse tests

pub fn sparse_filters_null_values_test() {
  let entries = [
    #("name", json.string("Alice")),
    #("age", json.null()),
    #("active", json.bool(True)),
  ]
  let result = json_util.sparse(entries)
  json.to_string(result)
  |> should.equal("{\"name\":\"Alice\",\"active\":true}")
}

pub fn sparse_with_no_nulls_test() {
  let entries = [
    #("a", json.int(1)),
    #("b", json.string("two")),
  ]
  let result = json_util.sparse(entries)
  json.to_string(result)
  |> should.equal("{\"a\":1,\"b\":\"two\"}")
}

pub fn sparse_with_all_nulls_test() {
  let entries = [
    #("a", json.null()),
    #("b", json.null()),
  ]
  let result = json_util.sparse(entries)
  json.to_string(result)
  |> should.equal("{}")
}

pub fn sparse_empty_list_test() {
  json_util.sparse([])
  |> json.to_string
  |> should.equal("{}")
}

// option_to_json tests

pub fn option_to_json_some_test() {
  json_util.option_to_json(Some(42), json.int)
  |> json.to_string
  |> should.equal("42")
}

pub fn option_to_json_none_test() {
  json_util.option_to_json(None, json.int)
  |> json.to_string
  |> should.equal("null")
}

pub fn option_to_json_with_string_encoder_test() {
  json_util.option_to_json(Some("hello"), json.string)
  |> json.to_string
  |> should.equal("\"hello\"")
}

pub fn option_to_json_with_bool_encoder_test() {
  json_util.option_to_json(Some(True), json.bool)
  |> json.to_string
  |> should.equal("true")
}

// decode tests using JSON parsing

pub fn decode_string_from_json_test() {
  let json_string = "{\"name\": \"Alice\"}"
  let decoder = json_util.decode_string("name")
  case json.parse(json_string, decoder) {
    Ok(value) -> value |> should.equal("Alice")
    Error(_) -> should.fail()
  }
}

pub fn decode_int_from_json_test() {
  let json_string = "{\"age\": 30}"
  let decoder = json_util.decode_int("age")
  case json.parse(json_string, decoder) {
    Ok(value) -> value |> should.equal(30)
    Error(_) -> should.fail()
  }
}

pub fn decode_float_from_json_test() {
  let json_string = "{\"score\": 9.5}"
  let decoder = json_util.decode_float("score")
  case json.parse(json_string, decoder) {
    Ok(value) -> value |> should.equal(9.5)
    Error(_) -> should.fail()
  }
}

pub fn decode_bool_from_json_test() {
  let json_string = "{\"active\": true}"
  let decoder = json_util.decode_bool("active")
  case json.parse(json_string, decoder) {
    Ok(value) -> value |> should.equal(True)
    Error(_) -> should.fail()
  }
}

// parse tests

pub fn parse_valid_json_test() {
  let result = json_util.parse("{\"key\": \"value\"}")
  case result {
    Ok(_) -> Nil
    Error(_) -> should.fail()
  }
}

pub fn parse_invalid_json_test() {
  json_util.parse("not json")
  |> should.be_error
}

pub fn parse_empty_object_test() {
  let result = json_util.parse("{}")
  case result {
    Ok(_) -> Nil
    Error(_) -> should.fail()
  }
}

pub fn parse_array_test() {
  let result = json_util.parse("[1, 2, 3]")
  case result {
    Ok(_) -> Nil
    Error(_) -> should.fail()
  }
}
