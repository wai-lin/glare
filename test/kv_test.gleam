import gleeunit
import gleeunit/should

import gflare/kv
import gleam/list
import gleam/option.{None, Some}

pub fn main() {
  gleeunit.main()
}

// GetOptions tests

pub fn get_options_default_test() {
  let opts = kv.get_options()
  opts.type_ |> should.equal("text")
  opts.cache_ttl |> should.equal(None)
}

pub fn get_options_with_json_test() {
  let opts = kv.get_options_with(type_: "json", cache_ttl: None)
  opts.type_ |> should.equal("json")
  opts.cache_ttl |> should.equal(None)
}

pub fn get_options_with_cache_ttl_test() {
  let opts = kv.get_options_with(type_: "text", cache_ttl: Some(60))
  opts.type_ |> should.equal("text")
  opts.cache_ttl |> should.equal(Some(60))
}

pub fn get_options_with_all_test() {
  let opts = kv.get_options_with(type_: "arrayBuffer", cache_ttl: Some(300))
  opts.type_ |> should.equal("arrayBuffer")
  opts.cache_ttl |> should.equal(Some(300))
}

// PutOptions tests

pub fn put_options_default_test() {
  let opts = kv.put_options()
  opts.expiration |> should.equal(None)
  opts.expiration_ttl |> should.equal(None)
}

pub fn put_options_with_expiration_test() {
  let opts =
    kv.put_options_with(expiration: Some(1_700_000_000), expiration_ttl: None)
  opts.expiration |> should.equal(Some(1_700_000_000))
  opts.expiration_ttl |> should.equal(None)
}

pub fn put_options_with_ttl_test() {
  let opts = kv.put_options_with(expiration: None, expiration_ttl: Some(3600))
  opts.expiration |> should.equal(None)
  opts.expiration_ttl |> should.equal(Some(3600))
}

pub fn put_options_with_all_test() {
  let opts =
    kv.put_options_with(
      expiration: Some(1_700_000_000),
      expiration_ttl: Some(60),
    )
  opts.expiration |> should.equal(Some(1_700_000_000))
  opts.expiration_ttl |> should.equal(Some(60))
}

// ListOptions tests

pub fn list_options_default_test() {
  let opts = kv.list_options()
  opts.prefix |> should.equal(None)
  opts.cursor |> should.equal(None)
  opts.limit |> should.equal(None)
  opts.reverse |> should.equal(None)
}

pub fn list_options_with_prefix_test() {
  let opts =
    kv.ListOptions(
      prefix: Some("user:"),
      cursor: None,
      limit: None,
      reverse: None,
    )
  opts.prefix |> should.equal(Some("user:"))
}

pub fn list_options_with_all_test() {
  let opts =
    kv.ListOptions(
      prefix: Some("session:"),
      cursor: Some("abc123"),
      limit: Some(100),
      reverse: Some(True),
    )
  opts.prefix |> should.equal(Some("session:"))
  opts.cursor |> should.equal(Some("abc123"))
  opts.limit |> should.equal(Some(100))
  opts.reverse |> should.equal(Some(True))
}

// KvKey tests

pub fn kv_key_construction_test() {
  let key = kv.KvKey(name: "user:123", metadata: None, expiration: None)
  key.name |> should.equal("user:123")
  key.metadata |> should.equal(None)
  key.expiration |> should.equal(None)
}

pub fn kv_key_with_expiration_test() {
  let key =
    kv.KvKey(name: "temp:key", metadata: None, expiration: Some(1_700_000_000))
  key.expiration |> should.equal(Some(1_700_000_000))
}

// ListResult tests

pub fn list_result_empty_test() {
  let result = kv.ListResult(keys: [], list_complete: True, cursor: None)
  result.keys |> should.equal([])
  result.list_complete |> should.equal(True)
  result.cursor |> should.equal(None)
}

pub fn list_result_with_cursor_test() {
  let result =
    kv.ListResult(
      keys: [],
      list_complete: False,
      cursor: Some("next_page_token"),
    )
  result.list_complete |> should.equal(False)
  result.cursor |> should.equal(Some("next_page_token"))
}

pub fn list_result_with_keys_test() {
  let keys = [
    kv.KvKey(name: "key1", metadata: None, expiration: None),
    kv.KvKey(name: "key2", metadata: None, expiration: None),
  ]
  let result = kv.ListResult(keys:, list_complete: True, cursor: None)
  list.length(result.keys) |> should.equal(2)
}

// GetWithMetadataResult tests

pub fn get_with_metadata_result_test() {
  let result = kv.GetWithMetadataResult(value: "hello", metadata: None)
  result.value |> should.equal("hello")
  result.metadata |> should.equal(None)
}

// Option encoding tests

pub fn option_int_some_test() {
  let opts = kv.put_options_with(expiration: Some(100), expiration_ttl: None)
  opts.expiration |> should.equal(Some(100))
}

pub fn option_int_none_test() {
  let opts = kv.put_options_with(expiration: None, expiration_ttl: None)
  opts.expiration |> should.equal(None)
}

pub fn option_string_some_test() {
  let opts =
    kv.ListOptions(
      prefix: Some("prefix"),
      cursor: None,
      limit: None,
      reverse: None,
    )
  opts.prefix |> should.equal(Some("prefix"))
}

pub fn option_string_none_test() {
  let opts = kv.list_options()
  opts.prefix |> should.equal(None)
}
