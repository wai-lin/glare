import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/javascript/promise.{type Promise}
import gleam/json.{type Json}
import gleam/option.{type Option, None, Some}
import glare/error.{type Error, DurableObjectError}

pub type Namespace
pub type Id
pub type Stub

pub fn id_from_name(
  namespace: Namespace,
  name: String,
) -> Id {
  do_id_from_name(namespace, name)
}

@external(javascript, "glare_ffi_do.mjs", "do_id_from_name")
fn do_id_from_name(namespace: Namespace, name: String) -> Id

pub fn id_from_string(
  namespace: Namespace,
  id: String,
) -> Id {
  do_id_from_string(namespace, id)
}

@external(javascript, "glare_ffi_do.mjs", "do_id_from_string")
fn do_id_from_string(namespace: Namespace, id: String) -> Id

pub fn get_stub(namespace: Namespace, id: Id) -> Stub {
  do_get_stub(namespace, id)
}

@external(javascript, "glare_ffi_do.mjs", "do_get_stub")
fn do_get_stub(namespace: Namespace, id: Id) -> Stub

pub type FetchOptions {
  FetchOptions(method: String, body: Option(Json))
}

pub fn fetch_options() -> FetchOptions {
  FetchOptions(method: "GET", body: None)
}

pub fn fetch_options_with(method method: String, body body: Option(Json)) -> FetchOptions {
  FetchOptions(method:, body:)
}

@external(javascript, "glare_ffi_do.mjs", "do_fetch")
fn do_fetch(
  stub: Stub,
  path: String,
  options: Json,
) -> Promise(Result(Dynamic, String))

pub fn fetch(
  stub: Stub,
  path: String,
  options: FetchOptions,
) -> Promise(Result(Dynamic, Error)) {
  let opts = json.object([
    #("method", json.string(options.method)),
    #("body", case options.body {
      Some(b) -> b
      None -> json.null()
    }),
  ])
  use result <- promise.await(do_fetch(stub, path, opts))
  case result {
    Ok(data) -> promise.resolve(Ok(data))
    Error(msg) -> promise.resolve(Error(DurableObjectError(msg)))
  }
}

@external(javascript, "glare_ffi_do.mjs", "do_get")
fn do_get(stub: Stub) -> Promise(Result(Dynamic, String))

pub fn get(stub: Stub) -> Promise(Result(Dynamic, Error)) {
  use result <- promise.await(do_get(stub))
  case result {
    Ok(data) -> promise.resolve(Ok(data))
    Error(msg) -> promise.resolve(Error(DurableObjectError(msg)))
  }
}

@external(javascript, "glare_ffi_do.mjs", "do_set")
fn do_set(stub: Stub, key: String, value: Json) -> Promise(Result(Dynamic, String))

pub fn set(
  stub: Stub,
  key: String,
  value: Json,
) -> Promise(Result(Nil, Error)) {
  use result <- promise.await(do_set(stub, key, value))
  case result {
    Ok(_) -> promise.resolve(Ok(Nil))
    Error(msg) -> promise.resolve(Error(DurableObjectError(msg)))
  }
}

@external(javascript, "glare_ffi_do.mjs", "do_delete")
fn do_delete_key(stub: Stub, key: String) -> Promise(Result(Dynamic, String))

pub fn delete_key(
  stub: Stub,
  key: String,
) -> Promise(Result(Nil, Error)) {
  use result <- promise.await(do_delete_key(stub, key))
  case result {
    Ok(_) -> promise.resolve(Ok(Nil))
    Error(msg) -> promise.resolve(Error(DurableObjectError(msg)))
  }
}

@external(javascript, "glare_ffi_do.mjs", "do_get_alarm")
fn do_get_alarm(stub: Stub) -> Promise(Result(Dynamic, String))

pub fn get_alarm(
  stub: Stub,
) -> Promise(Result(Option(Int), Error)) {
  use result <- promise.await(do_get_alarm(stub))
  case result {
    Ok(data) -> {
      case decode.run(data, decode.optional(decode.int)) {
        Ok(value) -> promise.resolve(Ok(value))
        Error(_) -> promise.resolve(Ok(None))
      }
    }
    Error(msg) -> promise.resolve(Error(DurableObjectError(msg)))
  }
}

@external(javascript, "glare_ffi_do.mjs", "do_set_alarm")
fn do_set_alarm(stub: Stub, timestamp: Int) -> Promise(Result(Dynamic, String))

pub fn set_alarm(
  stub: Stub,
  timestamp: Int,
) -> Promise(Result(Nil, Error)) {
  use result <- promise.await(do_set_alarm(stub, timestamp))
  case result {
    Ok(_) -> promise.resolve(Ok(Nil))
    Error(msg) -> promise.resolve(Error(DurableObjectError(msg)))
  }
}

@external(javascript, "glare_ffi_do.mjs", "do_delete_alarm")
fn do_delete_alarm(stub: Stub) -> Promise(Result(Dynamic, String))

pub fn delete_alarm(stub: Stub) -> Promise(Result(Nil, Error)) {
  use result <- promise.await(do_delete_alarm(stub))
  case result {
    Ok(_) -> promise.resolve(Ok(Nil))
    Error(msg) -> promise.resolve(Error(DurableObjectError(msg)))
  }
}
