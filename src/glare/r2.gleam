import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/javascript/promise.{type Promise}
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import glare/error.{type Error, R2Error}

pub type Bucket
pub type ObjectBody

pub type PutOptions {
  PutOptions(
    http_metadata: Option(HttpMetadata),
    custom_metadata: Option(List(#(String, String))),
  )
}

pub fn put_options() -> PutOptions {
  PutOptions(http_metadata: None, custom_metadata: None)
}

pub fn put_options_with(
  http_metadata meta: Option(HttpMetadata),
  custom_metadata cm: Option(List(#(String, String))),
) -> PutOptions {
  PutOptions(http_metadata: meta, custom_metadata: cm)
}

pub type HttpMetadata {
  HttpMetadata(
    content_type: Option(String),
    content_disposition: Option(String),
    content_encoding: Option(String),
    cache_control: Option(String),
    cache_expiry: Option(Int),
  )
}

pub type ListOptions {
  ListOptions(
    prefix: Option(String),
    cursor: Option(String),
    delimiter: Option(String),
    limit: Option(Int),
    include: Option(List(String)),
  )
}

pub fn list_options() -> ListOptions {
  ListOptions(
    prefix: None,
    cursor: None,
    delimiter: None,
    limit: None,
    include: None,
  )
}

pub fn list_options_with(
  prefix: Option(String),
  cursor: Option(String),
  delimiter: Option(String),
  limit: Option(Int),
  include: Option(List(String)),
) -> ListOptions {
  ListOptions(prefix:, cursor:, delimiter:, limit:, include:)
}

pub type ListObject {
  ListObject(
    key: String,
    version: String,
    size: Int,
    etag: String,
    uploaded: String,
  )
}

pub type ListResult {
  ListResult(
    objects: List(ListObject),
    truncated: Bool,
    cursor: Option(String),
    delimited_prefixes: List(String),
  )
}

pub type R2ObjectResult {
  R2ObjectResult(
    key: String,
    version: String,
    size: Int,
    etag: String,
    uploaded: String,
  )
}

@external(javascript, "glare_ffi_r2.mjs", "r2_get")
fn do_get(bucket: Bucket, key: String) -> Promise(Result(ObjectBody, String))

pub fn get(
  bucket: Bucket,
  key: String,
) -> Promise(Result(ObjectBody, Error)) {
  use result <- promise.await(do_get(bucket, key))
  case result {
    Ok(body) -> promise.resolve(Ok(body))
    Error(msg) -> promise.resolve(Error(R2Error(msg)))
  }
}

@external(javascript, "glare_ffi_r2.mjs", "r2_get_with_http_metadata")
fn do_get_meta(bucket: Bucket, key: String) -> Promise(Result(Dynamic, String))

pub fn get_metadata(
  bucket: Bucket,
  key: String,
) -> Promise(Result(R2ObjectResult, Error)) {
  use result <- promise.await(do_get_meta(bucket, key))
  case result {
    Ok(data) -> {
      case decode.run(data, decode_r2_object_result()) {
        Ok(r) -> promise.resolve(Ok(r))
        Error(_) ->
          promise.resolve(Error(R2Error("Failed to decode R2 object metadata")))
      }
    }
    Error(msg) -> promise.resolve(Error(R2Error(msg)))
  }
}

@external(javascript, "glare_ffi_r2.mjs", "r2_put")
fn do_put(
  bucket: Bucket,
  key: String,
  body: BitArray,
  options: json.Json,
) -> Promise(Result(Dynamic, String))

pub fn put(
  bucket: Bucket,
  key: String,
  body: BitArray,
  options: PutOptions,
) -> Promise(Result(R2ObjectResult, Error)) {
  let opts = encode_put_options(options)
  use result <- promise.await(do_put(bucket, key, body, opts))
  case result {
    Ok(data) -> {
      case decode.run(data, decode_r2_object_result()) {
        Ok(r) -> promise.resolve(Ok(r))
        Error(_) ->
          promise.resolve(Error(R2Error("Failed to decode R2 put result")))
      }
    }
    Error(msg) -> promise.resolve(Error(R2Error(msg)))
  }
}

@external(javascript, "glare_ffi_r2.mjs", "r2_delete")
fn do_delete(bucket: Bucket, keys: List(String)) -> Promise(Result(Dynamic, String))

pub fn delete(
  bucket: Bucket,
  key: String,
) -> Promise(Result(Nil, Error)) {
  use result <- promise.await(do_delete(bucket, [key]))
  case result {
    Ok(_) -> promise.resolve(Ok(Nil))
    Error(msg) -> promise.resolve(Error(R2Error(msg)))
  }
}

@external(javascript, "glare_ffi_r2.mjs", "r2_list")
fn do_list(bucket: Bucket, options: json.Json) -> Promise(Result(Dynamic, String))

pub fn list(
  bucket: Bucket,
  options: ListOptions,
) -> Promise(Result(ListResult, Error)) {
  let opts = encode_list_options(options)
  use result <- promise.await(do_list(bucket, opts))
  case result {
    Ok(data) -> {
      case decode.run(data, decode_list_result()) {
        Ok(r) -> promise.resolve(Ok(r))
        Error(_) ->
          promise.resolve(Error(R2Error("Failed to decode R2 list result")))
      }
    }
    Error(msg) -> promise.resolve(Error(R2Error(msg)))
  }
}

@external(javascript, "glare_ffi_r2.mjs", "r2_head")
fn do_head(bucket: Bucket, key: String) -> Promise(Result(Dynamic, String))

pub fn head(
  bucket: Bucket,
  key: String,
) -> Promise(Result(R2ObjectResult, Error)) {
  use result <- promise.await(do_head(bucket, key))
  case result {
    Ok(data) -> {
      case decode.run(data, decode_r2_object_result()) {
        Ok(r) -> promise.resolve(Ok(r))
        Error(_) ->
          promise.resolve(Error(R2Error("Failed to decode R2 head result")))
      }
    }
    Error(msg) -> promise.resolve(Error(R2Error(msg)))
  }
}

@external(javascript, "glare_ffi_r2.mjs", "r2_read_bytes")
fn do_read_bytes(body: ObjectBody) -> Promise(Result(BitArray, String))

pub fn read_bytes(
  body: ObjectBody,
) -> Promise(Result(BitArray, Error)) {
  use result <- promise.await(do_read_bytes(body))
  case result {
    Ok(bytes) -> promise.resolve(Ok(bytes))
    Error(msg) -> promise.resolve(Error(R2Error(msg)))
  }
}

@external(javascript, "glare_ffi_r2.mjs", "r2_read_text")
fn do_read_text(body: ObjectBody) -> Promise(Result(String, String))

pub fn read_text(
  body: ObjectBody,
) -> Promise(Result(String, Error)) {
  use result <- promise.await(do_read_text(body))
  case result {
    Ok(text) -> promise.resolve(Ok(text))
    Error(msg) -> promise.resolve(Error(R2Error(msg)))
  }
}

@external(javascript, "glare_ffi_r2.mjs", "r2_read_json")
fn do_read_json(body: ObjectBody) -> Promise(Result(Dynamic, String))

pub fn read_json(
  body: ObjectBody,
) -> Promise(Result(Dynamic, Error)) {
  use result <- promise.await(do_read_json(body))
  case result {
    Ok(data) -> promise.resolve(Ok(data))
    Error(msg) -> promise.resolve(Error(R2Error(msg)))
  }
}

fn encode_put_options(options: PutOptions) -> json.Json {
  json.object([
    #("http_metadata", option_to_json(options.http_metadata, encode_http_metadata)),
    #("custom_metadata", option_to_json(options.custom_metadata, fn(metadata) {
      json.object(list.map(metadata, fn(entry) {
        let #(k, v) = entry
        #(k, json.string(v))
      }))
    })),
  ])
}

fn encode_http_metadata(meta: HttpMetadata) -> json.Json {
  json.object([
    #("contentType", option_to_json(meta.content_type, json.string)),
    #("contentDisposition", option_to_json(meta.content_disposition, json.string)),
    #("contentEncoding", option_to_json(meta.content_encoding, json.string)),
    #("cacheControl", option_to_json(meta.cache_control, json.string)),
    #("cacheExpiry", option_to_json(meta.cache_expiry, json.int)),
  ])
}

fn encode_list_options(options: ListOptions) -> json.Json {
  json.object([
    #("prefix", option_to_json(options.prefix, json.string)),
    #("cursor", option_to_json(options.cursor, json.string)),
    #("delimiter", option_to_json(options.delimiter, json.string)),
    #("limit", option_to_json(options.limit, json.int)),
    #("include", option_to_json(options.include, fn(items) {
      json.array(items, json.string)
    })),
  ])
}

fn option_to_json(
  option: Option(a),
  encoder: fn(a) -> json.Json,
) -> json.Json {
  case option {
    Some(value) -> encoder(value)
    None -> json.null()
  }
}

fn decode_r2_object_result() {
  use key <- decode.field("key", decode.string)
  use version <- decode.field("version", decode.string)
  use size <- decode.field("size", decode.int)
  use etag <- decode.field("etag", decode.string)
  use uploaded <- decode.field("uploaded", decode.string)
  decode.success(R2ObjectResult(key:, version:, size:, etag:, uploaded:))
}

fn decode_list_result() {
  use objects <- decode.field("objects", decode.list(decode_list_object()))
  use truncated <- decode.field("truncated", decode.bool)
  use cursor <- decode.optional_field("cursor", None, decode.optional(decode.string))
  use delimited_prefixes <- decode.field(
    "delimited_prefixes",
    decode.list(decode.string),
  )
  decode.success(ListResult(objects:, truncated:, cursor:, delimited_prefixes:))
}

fn decode_list_object() {
  use key <- decode.field("key", decode.string)
  use version <- decode.field("version", decode.string)
  use size <- decode.field("size", decode.int)
  use etag <- decode.field("etag", decode.string)
  use uploaded <- decode.field("uploaded", decode.string)
  decode.success(ListObject(key:, version:, size:, etag:, uploaded:))
}
