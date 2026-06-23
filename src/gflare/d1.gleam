import gflare/error.{type Error, D1Error}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/javascript/promise.{type Promise}
import gleam/option.{type Option, None}

pub type Database

pub type PreparedStatement

pub type D1Result {
  D1Result(results: List(Dynamic), success: Bool, meta: D1Meta)
}

pub type D1Meta {
  D1Meta(
    changed_db: Option(Bool),
    last_row_id: Option(Int),
    rows_read: Option(Int),
    rows_written: Option(Int),
    size_after_bytes: Option(Int),
    size_before_bytes: Option(Int),
    duration_ms: Option(Float),
  )
}

pub type Row =
  Dynamic

pub fn int(value: Int) -> Dynamic {
  do_int(value)
}

pub fn float(value: Float) -> Dynamic {
  do_float(value)
}

pub fn text(value: String) -> Dynamic {
  do_text(value)
}

pub fn bool(value: Bool) -> Dynamic {
  do_bool(value)
}

pub fn blob(value: BitArray) -> Dynamic {
  do_blob(value)
}

pub fn null_value() -> Dynamic {
  do_null()
}

@external(javascript, "../gflare_ffi_d1.mjs", "d1_int")
fn do_int(value: Int) -> Dynamic

@external(javascript, "../gflare_ffi_d1.mjs", "d1_float")
fn do_float(value: Float) -> Dynamic

@external(javascript, "../gflare_ffi_d1.mjs", "d1_text")
fn do_text(value: String) -> Dynamic

@external(javascript, "../gflare_ffi_d1.mjs", "d1_bool")
fn do_bool(value: Bool) -> Dynamic

@external(javascript, "../gflare_ffi_d1.mjs", "d1_blob")
fn do_blob(value: BitArray) -> Dynamic

@external(javascript, "../gflare_ffi_d1.mjs", "d1_null")
fn do_null() -> Dynamic

@external(javascript, "../gflare_ffi_d1.mjs", "d1_prepare")
pub fn prepare(db: Database, query: String) -> PreparedStatement

@external(javascript, "../gflare_ffi_d1.mjs", "d1_bind")
pub fn bind(
  statement: PreparedStatement,
  values: List(Dynamic),
) -> PreparedStatement

@external(javascript, "../gflare_ffi_d1.mjs", "d1_run")
fn do_run(statement: PreparedStatement) -> Promise(Result(Dynamic, String))

pub fn run(statement: PreparedStatement) -> Promise(Result(D1Result, Error)) {
  use result <- promise.await(do_run(statement))
  case result {
    Ok(data) -> {
      case decode.run(data, decode_d1_result()) {
        Ok(r) -> promise.resolve(Ok(r))
        Error(_) ->
          promise.resolve(Error(D1Error("Failed to decode D1 result")))
      }
    }
    Error(msg) -> promise.resolve(Error(D1Error(msg)))
  }
}

@external(javascript, "../gflare_ffi_d1.mjs", "d1_first")
fn do_first(statement: PreparedStatement) -> Promise(Result(Dynamic, String))

pub fn first(
  statement: PreparedStatement,
) -> Promise(Result(Option(Row), Error)) {
  use result <- promise.await(do_first(statement))
  case result {
    Ok(data) -> {
      case decode.run(data, decode.optional(decode.dynamic)) {
        Ok(value) -> promise.resolve(Ok(value))
        Error(_) -> promise.resolve(Ok(None))
      }
    }
    Error(msg) -> promise.resolve(Error(D1Error(msg)))
  }
}

@external(javascript, "../gflare_ffi_d1.mjs", "d1_all")
fn do_all(statement: PreparedStatement) -> Promise(Result(Dynamic, String))

pub fn all(statement: PreparedStatement) -> Promise(Result(D1Result, Error)) {
  use result <- promise.await(do_all(statement))
  case result {
    Ok(data) -> {
      case decode.run(data, decode_d1_result()) {
        Ok(r) -> promise.resolve(Ok(r))
        Error(_) ->
          promise.resolve(Error(D1Error("Failed to decode D1 result")))
      }
    }
    Error(msg) -> promise.resolve(Error(D1Error(msg)))
  }
}

@external(javascript, "../gflare_ffi_d1.mjs", "d1_exec")
fn do_exec(db: Database, query: String) -> Promise(Result(Dynamic, String))

pub fn exec(
  db: Database,
  query: String,
) -> Promise(Result(D1Result, Error)) {
  use result <- promise.await(do_exec(db, query))
  case result {
    Ok(data) -> {
      case decode.run(data, decode_d1_result()) {
        Ok(r) -> promise.resolve(Ok(r))
        Error(_) ->
          promise.resolve(Error(D1Error("Failed to decode D1 result")))
      }
    }
    Error(msg) -> promise.resolve(Error(D1Error(msg)))
  }
}

fn decode_d1_result() {
  use results <- decode.field("results", decode.list(decode.dynamic))
  use success <- decode.field("success", decode.bool)
  use meta <- decode.field("meta", decode_d1_meta())
  decode.success(D1Result(results:, success:, meta:))
}

fn decode_d1_meta() {
  use changed_db <- decode.optional_field(
    "changed_db",
    None,
    decode.optional(decode.bool),
  )
  use last_row_id <- decode.optional_field(
    "last_row_id",
    None,
    decode.optional(decode.int),
  )
  use rows_read <- decode.optional_field(
    "rows_read",
    None,
    decode.optional(decode.int),
  )
  use rows_written <- decode.optional_field(
    "rows_written",
    None,
    decode.optional(decode.int),
  )
  use size_after_bytes <- decode.optional_field(
    "size_after_bytes",
    None,
    decode.optional(decode.int),
  )
  use size_before_bytes <- decode.optional_field(
    "size_before_bytes",
    None,
    decode.optional(decode.int),
  )
  use duration_ms <- decode.optional_field(
    "duration_ms",
    None,
    decode.optional(decode.float),
  )
  decode.success(D1Meta(
    changed_db:,
    last_row_id:,
    rows_read:,
    rows_written:,
    size_after_bytes:,
    size_before_bytes:,
    duration_ms:,
  ))
}
