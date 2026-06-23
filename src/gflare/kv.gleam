import gflare/error.{type Error, KvError}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/javascript/promise.{type Promise}
import gleam/json
import gleam/option.{type Option, None, Some}

pub type Kv

pub type GetOptions {
  GetOptions(type_: String, cache_ttl: Option(Int))
}

pub fn get_options() -> GetOptions {
  GetOptions(type_: "text", cache_ttl: None)
}

pub fn get_options_with(type_ type_: String, cache_ttl ttl) -> GetOptions {
  GetOptions(type_: type_, cache_ttl: ttl)
}

pub type PutOptions {
  PutOptions(expiration: Option(Int), expiration_ttl: Option(Int))
}

pub fn put_options() -> PutOptions {
  PutOptions(expiration: None, expiration_ttl: None)
}

pub fn put_options_with(
  expiration exp: Option(Int),
  expiration_ttl ttl: Option(Int),
) -> PutOptions {
  PutOptions(expiration: exp, expiration_ttl: ttl)
}

pub type ListOptions {
  ListOptions(
    prefix: Option(String),
    cursor: Option(String),
    limit: Option(Int),
    reverse: Option(Bool),
  )
}

pub fn list_options() -> ListOptions {
  ListOptions(prefix: None, cursor: None, limit: None, reverse: None)
}

pub type KvKey {
  KvKey(name: String, metadata: Option(Dynamic), expiration: Option(Int))
}

pub type ListResult {
  ListResult(keys: List(KvKey), list_complete: Bool, cursor: Option(String))
}

pub type GetWithMetadataResult {
  GetWithMetadataResult(value: Option(String), metadata: Option(Dynamic))
}

@external(javascript, "../gflare_ffi_kv.mjs", "kv_get")
fn do_get(
  namespace: Kv,
  key: String,
  options: json.Json,
) -> Promise(Result(String, String))

pub fn get(
  namespace: Kv,
  key: String,
  options: GetOptions,
) -> Promise(Result(String, Error)) {
  let opts =
    json.object([
      #("type_", json.string(options.type_)),
      #("cache_ttl", option_int_to_json(options.cache_ttl)),
    ])
  use result <- promise.await(do_get(namespace, key, opts))
  case result {
    Ok(value) -> promise.resolve(Ok(value))
    Error(msg) -> promise.resolve(Error(KvError(msg)))
  }
}

@external(javascript, "../gflare_ffi_kv.mjs", "kv_get_with_metadata")
fn do_get_with_metadata(
  namespace: Kv,
  key: String,
  options: json.Json,
) -> Promise(Result(Dynamic, String))

pub fn get_with_metadata(
  namespace: Kv,
  key: String,
  options: GetOptions,
) -> Promise(Result(GetWithMetadataResult, Error)) {
  let opts =
    json.object([
      #("type_", json.string(options.type_)),
      #("cache_ttl", option_int_to_json(options.cache_ttl)),
    ])
  use result <- promise.await(do_get_with_metadata(namespace, key, opts))
  case result {
    Ok(data) -> {
      case decode.run(data, decode_get_with_metadata_result()) {
        Ok(r) -> promise.resolve(Ok(r))
        Error(_) -> promise.resolve(Error(KvError("Failed to decode response")))
      }
    }
    Error(msg) -> promise.resolve(Error(KvError(msg)))
  }
}

fn decode_get_with_metadata_result() {
  use value <- decode.optional_field(
    "value",
    None,
    decode.optional(decode.string),
  )
  use metadata <- decode.optional_field(
    "metadata",
    None,
    decode.optional(decode.dynamic),
  )
  decode.success(GetWithMetadataResult(value: value, metadata: metadata))
}

@external(javascript, "../gflare_ffi_kv.mjs", "kv_put")
fn do_put(
  namespace: Kv,
  key: String,
  value: String,
  options: json.Json,
) -> Promise(Result(Dynamic, String))

pub fn put(
  namespace: Kv,
  key: String,
  value: String,
  options: PutOptions,
) -> Promise(Result(Nil, Error)) {
  let opts =
    json.object([
      #("expiration", option_int_to_json(options.expiration)),
      #("expiration_ttl", option_int_to_json(options.expiration_ttl)),
    ])
  use result <- promise.await(do_put(namespace, key, value, opts))
  case result {
    Ok(_) -> promise.resolve(Ok(Nil))
    Error(msg) -> promise.resolve(Error(KvError(msg)))
  }
}

@external(javascript, "../gflare_ffi_kv.mjs", "kv_delete")
fn do_delete(namespace: Kv, key: String) -> Promise(Result(Dynamic, String))

pub fn delete(namespace: Kv, key: String) -> Promise(Result(Nil, Error)) {
  use result <- promise.await(do_delete(namespace, key))
  case result {
    Ok(_) -> promise.resolve(Ok(Nil))
    Error(msg) -> promise.resolve(Error(KvError(msg)))
  }
}

@external(javascript, "../gflare_ffi_kv.mjs", "kv_list")
fn do_list(
  namespace: Kv,
  options: json.Json,
) -> Promise(Result(Dynamic, String))

pub fn list(
  namespace: Kv,
  options: ListOptions,
) -> Promise(Result(ListResult, Error)) {
  let opts =
    json.object([
      #("prefix", option_string_to_json(options.prefix)),
      #("cursor", option_string_to_json(options.cursor)),
      #("limit", option_int_to_json(options.limit)),
      #("reverse", option_bool_to_json(options.reverse)),
    ])
  use result <- promise.await(do_list(namespace, opts))
  case result {
    Ok(data) -> {
      case decode.run(data, decode_list_result()) {
        Ok(r) -> promise.resolve(Ok(r))
        Error(_) ->
          promise.resolve(Error(KvError("Failed to decode list result")))
      }
    }
    Error(msg) -> promise.resolve(Error(KvError(msg)))
  }
}

fn decode_list_result() {
  use keys <- decode.field("keys", decode.list(decode_kv_key()))
  use list_complete <- decode.field("list_complete", decode.bool)
  use cursor <- decode.optional_field(
    "cursor",
    None,
    decode.optional(decode.string),
  )
  decode.success(ListResult(
    keys: keys,
    list_complete: list_complete,
    cursor: cursor,
  ))
}

fn decode_kv_key() {
  use name <- decode.field("name", decode.string)
  use metadata <- decode.optional_field(
    "metadata",
    None,
    decode.optional(decode.dynamic),
  )
  use expiration <- decode.optional_field(
    "expiration",
    None,
    decode.optional(decode.int),
  )
  decode.success(KvKey(name: name, metadata: metadata, expiration: expiration))
}

fn option_int_to_json(option: Option(Int)) -> json.Json {
  case option {
    Some(value) -> json.int(value)
    None -> json.null()
  }
}

fn option_string_to_json(option: Option(String)) -> json.Json {
  case option {
    Some(value) -> json.string(value)
    None -> json.null()
  }
}

fn option_bool_to_json(option: Option(Bool)) -> json.Json {
  case option {
    Some(value) -> json.bool(value)
    None -> json.null()
  }
}
