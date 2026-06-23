import gleeunit
import gleeunit/should

import gflare/cookie
import gflare/session
import gleam/option.{None, Some}

pub fn main() {
  gleeunit.main()
}

// SessionConfig tests

pub fn default_config_test() {
  let config = session.default_config("MY_KV")
  config.cookie_name |> should.equal("sid")
  config.kv_name |> should.equal("MY_KV")
  config.ttl |> should.equal(86_400)
  config.secure |> should.equal(True)
  config.same_site |> should.equal(cookie.Lax)
}

pub fn default_config_custom_kv_test() {
  let config = session.default_config("SESSIONS")
  config.kv_name |> should.equal("SESSIONS")
}

// SessionData tests

pub fn session_data_construction_test() {
  let session =
    session.SessionData(id: "abc123", data: [#("user_id", "1"), #(
      "role",
      "admin",
    )])
  session.id |> should.equal("abc123")
  session.data |> should.equal([#("user_id", "1"), #("role", "admin")])
}

pub fn set_value_test() {
  let s = session.SessionData(id: "abc", data: [])
  let s = session.set_value(s, "user_id", "42")
  session.get_value(s, "user_id") |> should.equal(Some("42"))
}

pub fn set_value_overwrite_test() {
  let s = session.SessionData(id: "abc", data: [#("key", "old")])
  let s = session.set_value(s, "key", "new")
  session.get_value(s, "key") |> should.equal(Some("new"))
  s.data |> should.equal([#("key", "new")])
}

pub fn get_value_missing_test() {
  let s = session.SessionData(id: "abc", data: [])
  session.get_value(s, "missing") |> should.equal(None)
}

pub fn remove_value_test() {
  let s =
    session.SessionData(id: "abc", data: [#("a", "1"), #("b", "2"), #(
      "c",
      "3",
    )])
  let s = session.remove_value(s, "b")
  session.get_value(s, "a") |> should.equal(Some("1"))
  session.get_value(s, "b") |> should.equal(None)
  session.get_value(s, "c") |> should.equal(Some("3"))
}

pub fn remove_value_missing_test() {
  let s = session.SessionData(id: "abc", data: [#("a", "1")])
  let s = session.remove_value(s, "missing")
  s.data |> should.equal([#("a", "1")])
}

pub fn set_multiple_values_test() {
  let s = session.SessionData(id: "abc", data: [])
  let s = session.set_value(s, "a", "1")
  let s = session.set_value(s, "b", "2")
  let s = session.set_value(s, "c", "3")
  session.get_value(s, "a") |> should.equal(Some("1"))
  session.get_value(s, "b") |> should.equal(Some("2"))
  session.get_value(s, "c") |> should.equal(Some("3"))
}
