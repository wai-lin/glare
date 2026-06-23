import gflare/bindings
import gflare/cookie
import gflare/error
import gflare/kv
import gflare/log
import gflare/request.{type HttpRequest}
import gflare/response.{type Response}
import gflare/router
import gleam/dict as gleam_dict
import gleam/dynamic/decode
import gleam/json
import gleam/javascript/promise
import gleam/list
import gleam/option.{type Option, None, Some}

pub type SessionConfig {
  SessionConfig(
    cookie_name: String,
    kv_name: String,
    ttl: Int,
    secure: Bool,
    same_site: cookie.SameSite,
  )
}

pub type SessionData {
  SessionData(id: String, data: List(#(String, String)))
}

// Middleware

pub fn middleware(config: SessionConfig) -> router.Middleware {
  router.Middleware(fn(req, env, ctx, next) {
    use session_data <- promise.await(load_session(req, env, config))

    let session_json = encode_session(session_data)
    let enriched_req =
      clone_with_header(req, "x-gflare-session", session_json)

    let router.Handler(handler_fn) = next
    use resp <- promise.await(handler_fn(
      enriched_req,
      env,
      ctx,
      router.RouteParams([]),
    ))

    let opts =
      cookie.default_options()
      |> cookie.set_secure(config.secure)
      |> cookie.set_same_site(config.same_site)
      |> cookie.set_max_age(config.ttl)
    let resp = cookie.set(resp, config.cookie_name, session_data.id, opts)

    case get_response_header(resp, "x-gflare-session-save") {
      Ok(saved_json) -> {
        let resp = remove_response_header(resp, "x-gflare-session-save")
        case decode_session_json(saved_json) {
          Ok(saved_data) -> {
            use _ <- promise.await(save_session(saved_data, env, config))
            promise.resolve(resp)
          }
          Error(_) -> promise.resolve(resp)
        }
      }
      Error(_) -> promise.resolve(resp)
    }
  })
}

// Handler API

pub fn get(request: HttpRequest) -> Result(SessionData, String) {
  case get_request_header(request, "x-gflare-session") {
    Ok(json_str) -> decode_session_json(json_str)
    Error(_) -> Error("No session found in request")
  }
}

pub fn save(response: Response, session: SessionData) -> Response {
  let session_json = encode_session(session)
  response.set_header(response, "x-gflare-session-save", session_json)
}

pub fn set_value(
  session: SessionData,
  key: String,
  value: String,
) -> SessionData {
  let updated =
    list.filter(session.data, fn(pair) { pair.0 != key })
    |> list.append([#(key, value)])
  SessionData(..session, data: updated)
}

pub fn get_value(session: SessionData, key: String) -> Option(String) {
  case list.find(session.data, fn(pair) { pair.0 == key }) {
    Ok(#(_, value)) -> Some(value)
    Error(_) -> None
  }
}

pub fn remove_value(session: SessionData, key: String) -> SessionData {
  let updated = list.filter(session.data, fn(pair) { pair.0 != key })
  SessionData(..session, data: updated)
}

// Config

pub fn default_config(kv_name: String) -> SessionConfig {
  SessionConfig(
    cookie_name: "sid",
    kv_name:,
    ttl: 86_400,
    secure: True,
    same_site: cookie.Lax,
  )
}

// Internal: session loading

fn load_session(
  request: HttpRequest,
  env: bindings.Env,
  config: SessionConfig,
) -> promise.Promise(SessionData) {
  case cookie.get(request, config.cookie_name) {
    Some(session_id) -> {
      case bindings.kv(env, config.kv_name) {
        Ok(kv_namespace) -> {
          use result <- promise.await(kv.get(
            kv_namespace,
            "session:" <> session_id,
            kv.get_options(),
          ))
          case result {
            Ok(json_str) ->
              case decode_session_json(json_str) {
                Ok(data) -> promise.resolve(data)
                Error(_) ->
                  promise.resolve(SessionData(id: session_id, data: []))
              }
            Error(_) ->
              promise.resolve(SessionData(id: session_id, data: []))
          }
        }
        Error(_) ->
          promise.resolve(SessionData(
            id: log.generate_request_id(),
            data: [],
          ))
      }
    }
    None ->
      promise.resolve(SessionData(id: log.generate_request_id(), data: []))
  }
}

fn save_session(
  session: SessionData,
  env: bindings.Env,
  config: SessionConfig,
) -> promise.Promise(Result(Nil, String)) {
  case bindings.kv(env, config.kv_name) {
    Ok(kv_namespace) -> {
      let session_json = encode_session(session)
      let opts =
        kv.put_options_with(expiration: None, expiration_ttl: Some(config.ttl))
      use result <- promise.await(kv.put(
        kv_namespace,
        "session:" <> session.id,
        session_json,
        opts,
      ))
      case result {
        Ok(_) -> promise.resolve(Ok(Nil))
        Error(e) -> promise.resolve(Error(error.to_string(e)))
      }
    }
    Error(e) -> promise.resolve(Error(error.to_string(e)))
  }
}

// Internal: JSON encoding/decoding

fn encode_session(session: SessionData) -> String {
  let data_pairs =
    list.map(session.data, fn(pair) {
      #(pair.0, json.string(pair.1))
    })
  json.to_string(json.object([#("id", json.string(session.id)), #(
    "data",
    json.object(data_pairs),
  )]))
}

fn decode_session_json(json_str: String) -> Result(SessionData, String) {
  case json.parse(json_str, decode.dynamic) {
    Ok(data) -> {
      case decode.run(data, decode.field("id", decode.string, decode.success)) {
        Ok(id) -> {
          let session_data = case
            decode.run(
              data,
              decode.field("data", decode.dict(decode.string, decode.string), decode.success)
            )
          {
            Ok(dict) -> gleam_dict.to_list(dict)
            Error(_) -> []
          }
          Ok(SessionData(id:, data: session_data))
        }
        Error(_) -> Error("Missing or invalid 'id' field")
      }
    }
    Error(_) -> Error("Invalid session JSON")
  }
}

// Internal: header helpers

fn get_request_header(
  request: HttpRequest,
  name: String,
) -> Result(String, String) {
  let headers = request.headers(request)
  case list.find(headers, fn(h) { h.0 == name }) {
    Ok(#(_, value)) -> Ok(value)
    Error(_) -> Error("Header not found: " <> name)
  }
}

fn remove_response_header(
  response: Response,
  name: String,
) -> Response {
  do_remove_response_header(response, name)
}

// FFI

@external(javascript, "../gflare_ffi_session.mjs", "clone_with_header")
fn clone_with_header(
  request: HttpRequest,
  name: String,
  value: String,
) -> HttpRequest

@external(javascript, "../gflare_ffi_worker.mjs", "get_response_header")
fn get_response_header(
  response: Response,
  name: String,
) -> Result(String, String)

@external(javascript, "../gflare_ffi_worker.mjs", "remove_response_header")
fn do_remove_response_header(response: Response, name: String) -> Response
