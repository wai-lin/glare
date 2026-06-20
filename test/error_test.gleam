import gleeunit
import gleeunit/should

import glare/error

pub fn main() {
  gleeunit.main()
}

pub fn kv_error_test() {
  error.KvError("not found")
  |> error.to_string
  |> should.equal("KV error: not found")
}

pub fn d1_error_test() {
  error.D1Error("query failed")
  |> error.to_string
  |> should.equal("D1 error: query failed")
}

pub fn r2_error_test() {
  error.R2Error("bucket missing")
  |> error.to_string
  |> should.equal("R2 error: bucket missing")
}

pub fn durable_object_error_test() {
  error.DurableObjectError("stub error")
  |> error.to_string
  |> should.equal("Durable Object error: stub error")
}

pub fn queue_error_test() {
  error.QueueError("send failed")
  |> error.to_string
  |> should.equal("Queue error: send failed")
}

pub fn binding_not_found_test() {
  error.BindingNotFound("MY_KV")
  |> error.to_string
  |> should.equal("Binding not found: MY_KV")
}

pub fn encoding_error_test() {
  error.EncodingError("invalid json")
  |> error.to_string
  |> should.equal("Encoding error: invalid json")
}

pub fn decoding_error_test() {
  error.DecodingError("missing field")
  |> error.to_string
  |> should.equal("Decoding error: missing field")
}

pub fn error_with_empty_message_test() {
  error.KvError("")
  |> error.to_string
  |> should.equal("KV error: ")
}

pub fn error_with_special_chars_test() {
  error.D1Error("query \"SELECT *\" failed")
  |> error.to_string
  |> should.equal("D1 error: query \"SELECT *\" failed")
}
