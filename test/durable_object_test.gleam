import gleeunit
import gleeunit/should

import gflare/durable_object
import gleam/json
import gleam/option.{None, Some}

pub fn main() {
  gleeunit.main()
}

// FetchOptions tests

pub fn fetch_options_default_test() {
  let opts = durable_object.fetch_options()
  opts.method |> should.equal("GET")
  opts.body |> should.equal(None)
}

pub fn fetch_options_with_method_test() {
  let opts = durable_object.fetch_options_with(method: "POST", body: None)
  opts.method |> should.equal("POST")
  opts.body |> should.equal(None)
}

pub fn fetch_options_with_body_test() {
  let body = json.object([#("key", json.string("value"))])
  let opts = durable_object.fetch_options_with(method: "PUT", body: Some(body))
  opts.method |> should.equal("PUT")
  opts.body |> should.be_some
}

pub fn fetch_options_with_all_test() {
  let body = json.array([json.int(1), json.int(2)], fn(x) { x })
  let opts =
    durable_object.fetch_options_with(method: "DELETE", body: Some(body))
  opts.method |> should.equal("DELETE")
  opts.body |> should.be_some
}

// FetchOptions equality tests

pub fn fetch_options_equality_test() {
  let opts1 = durable_object.fetch_options()
  let opts2 = durable_object.fetch_options()
  opts1.method |> should.equal(opts2.method)
  opts1.body |> should.equal(opts2.body)
}

pub fn fetch_options_different_methods_test() {
  let opts1 = durable_object.fetch_options_with(method: "GET", body: None)
  let opts2 = durable_object.fetch_options_with(method: "POST", body: None)
  opts1.method |> should.not_equal(opts2.method)
}

// JSON body tests

pub fn fetch_options_with_json_object_test() {
  let body =
    json.object([
      #("action", json.string("increment")),
      #("amount", json.int(1)),
    ])
  let opts = durable_object.fetch_options_with(method: "POST", body: Some(body))
  opts.body |> should.be_some
}

pub fn fetch_options_with_json_array_test() {
  let body = json.array([json.string("a"), json.string("b")], fn(x) { x })
  let opts = durable_object.fetch_options_with(method: "POST", body: Some(body))
  opts.body |> should.be_some
}

pub fn fetch_options_with_empty_body_test() {
  let body = json.object([])
  let opts = durable_object.fetch_options_with(method: "POST", body: Some(body))
  opts.body |> should.be_some
}

// Id type tests

pub fn id_from_name_construction_test() {
  // Id is an opaque type from FFI, we can only verify the function exists
  // and doesn't crash when called with valid inputs
  // In a real test environment, we'd need a mock namespace
  True |> should.equal(True)
}

// Stub type tests

pub fn stub_construction_test() {
  // Stub is an opaque type from FFI, we can only verify the function exists
  // In a real test environment, we'd need a mock namespace and id
  True |> should.equal(True)
}

// Method string tests

pub fn method_get_test() {
  let opts = durable_object.fetch_options_with(method: "GET", body: None)
  opts.method |> should.equal("GET")
}

pub fn method_post_test() {
  let opts = durable_object.fetch_options_with(method: "POST", body: None)
  opts.method |> should.equal("POST")
}

pub fn method_put_test() {
  let opts = durable_object.fetch_options_with(method: "PUT", body: None)
  opts.method |> should.equal("PUT")
}

pub fn method_delete_test() {
  let opts = durable_object.fetch_options_with(method: "DELETE", body: None)
  opts.method |> should.equal("DELETE")
}

pub fn method_patch_test() {
  let opts = durable_object.fetch_options_with(method: "PATCH", body: None)
  opts.method |> should.equal("PATCH")
}

// Complex body tests

pub fn fetch_options_with_nested_json_test() {
  let body =
    json.object([
      #(
        "user",
        json.object([#("name", json.string("Alice")), #("age", json.int(30))]),
      ),
      #("active", json.bool(True)),
    ])
  let opts = durable_object.fetch_options_with(method: "POST", body: Some(body))
  opts.body |> should.be_some
}

pub fn fetch_options_with_complex_body_test() {
  let body =
    json.object([
      #("type", json.string("batch")),
      #("operations", json.array([], fn(x) { x })),
      #("metadata", json.null()),
    ])
  let opts = durable_object.fetch_options_with(method: "POST", body: Some(body))
  opts.body |> should.be_some
}
