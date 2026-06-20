import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/javascript/promise.{type Promise}
import gleam/option.{type Option, None}
import glare/error.{type Error, D1Error}

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

pub type Row = Dynamic

pub type D1ExecResult {
  D1ExecResult(
    results: List(Dynamic),
    success: Bool,
    meta: D1Meta,
  )
}

@external(javascript, "glare_ffi_d1.mjs", "d1_prepare")
pub fn prepare(db: Database, query: String) -> PreparedStatement

@external(javascript, "glare_ffi_d1.mjs", "d1_bind")
pub fn bind(
  statement: PreparedStatement,
  values: List(Dynamic),
) -> PreparedStatement

@external(javascript, "glare_ffi_d1.mjs", "d1_run")
fn do_run(statement: PreparedStatement) -> Promise(Result(Dynamic, String))

pub fn run(
  statement: PreparedStatement,
) -> Promise(Result(D1Result, Error)) {
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

@external(javascript, "glare_ffi_d1.mjs", "d1_first")
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

@external(javascript, "glare_ffi_d1.mjs", "d1_all")
fn do_all(statement: PreparedStatement) -> Promise(Result(Dynamic, String))

pub fn all(
  statement: PreparedStatement,
) -> Promise(Result(D1Result, Error)) {
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

@external(javascript, "glare_ffi_d1.mjs", "d1_exec")
fn do_exec(db: Database, query: String) -> Promise(Result(Dynamic, String))

pub fn exec(
  db: Database,
  query: String,
) -> Promise(Result(D1ExecResult, Error)) {
  use result <- promise.await(do_exec(db, query))
  case result {
    Ok(data) -> {
      case decode.run(data, decode_d1_exec_result()) {
        Ok(r) -> promise.resolve(Ok(r))
        Error(_) ->
          promise.resolve(Error(D1Error("Failed to decode D1 exec result")))
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

fn decode_d1_exec_result() {
  use results <- decode.field("results", decode.list(decode.dynamic))
  use success <- decode.field("success", decode.bool)
  use meta <- decode.field("meta", decode_d1_meta())
  decode.success(D1ExecResult(results:, success:, meta:))
}

fn decode_d1_meta() {
  use changed_db <- decode.optional_field("changed_db", None, decode.optional(decode.bool))
  use last_row_id <- decode.optional_field("last_row_id", None, decode.optional(decode.int))
  use rows_read <- decode.optional_field("rows_read", None, decode.optional(decode.int))
  use rows_written <- decode.optional_field("rows_written", None, decode.optional(decode.int))
  use size_after_bytes <- decode.optional_field("size_after_bytes", None, decode.optional(decode.int))
  use size_before_bytes <- decode.optional_field("size_before_bytes", None, decode.optional(decode.int))
  use duration_ms <- decode.optional_field("duration_ms", None, decode.optional(decode.float))
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
