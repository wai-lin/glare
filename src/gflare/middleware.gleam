import gflare/log.{type Logger}
import gflare/request.{type HttpRequest}
import gflare/response.{type Response}
import gflare/worker.{type Context}
import gleam/javascript/promise.{type Promise}
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

pub type Env

pub type MiddlewareConfig {
  MiddlewareConfig(
    log_request_body: Bool,
    log_response_body: Bool,
    log_headers: Bool,
    exclude_paths: List(String),
  )
}

pub fn default_config() -> MiddlewareConfig {
  MiddlewareConfig(
    log_request_body: False,
    log_response_body: False,
    log_headers: False,
    exclude_paths: ["/health", "/healthz", "/ready", "/readyz"],
  )
}

pub fn with_logging(
  logger: Logger,
  config: MiddlewareConfig,
  request: HttpRequest,
  env: Env,
  ctx: Context,
  handler: fn(HttpRequest, Env, Context) -> Promise(Response),
) -> Promise(Response) {
  let request_id = log.generate_request_id()
  let path = get_path(request.url(request))

  // Check if path should be excluded
  case list.contains(config.exclude_paths, path) {
    True -> handler(request, env, ctx)
    False -> {
      // Log request start
      log_request_start(logger, request, request_id, config)

      // Get start time
      let start_time = get_current_time()

      // Execute handler
      use response <- promise.await(handler(request, env, ctx))

      // Calculate duration
      let end_time = get_current_time()
      let duration_ms = end_time -. start_time

      // Log request end
      log_request_end(
        logger,
        request,
        response,
        request_id,
        duration_ms,
        config,
      )

      promise.resolve(response)
    }
  }
}

pub fn log_request_start(
  logger: Logger,
  request: HttpRequest,
  request_id: String,
  config: MiddlewareConfig,
) -> Nil {
  let method = request.method(request)
  let url = request.url(request)
  let path = get_path(url)

  let mut_context = [
    #("request_id", json.string(request_id)),
    #("method", json.string(method)),
    #("path", json.string(path)),
  ]

  let context = case config.log_headers {
    True -> {
      let headers = request.headers(request)
      let headers_json =
        list.map(headers, fn(h) { #("value", json.string(h.1)) })
        |> json.object
      list.append(mut_context, [#("headers", headers_json)])
    }
    False -> mut_context
  }

  log.info(logger, method <> " " <> path, context)
}

pub fn log_request_end(
  logger: Logger,
  request: HttpRequest,
  response: Response,
  request_id: String,
  duration_ms: Float,
  config: MiddlewareConfig,
) -> Nil {
  let method = request.method(request)
  let url = request.url(request)
  let path = get_path(url)
  let status = response_status(response)

  let mut_context = [
    #("request_id", json.string(request_id)),
    #("method", json.string(method)),
    #("path", json.string(path)),
    #("status", json.int(status)),
    #("duration_ms", json.float(duration_ms)),
  ]

  let context = case config.log_response_body {
    True -> {
      let body = response_body(response)
      case body {
        Some(body_str) ->
          list.append(mut_context, [#("response_body", json.string(body_str))])
        None -> mut_context
      }
    }
    False -> mut_context
  }

  let message =
    method
    <> " "
    <> path
    <> " "
    <> int_to_string(status)
    <> " "
    <> float_to_string(duration_ms)
    <> "ms"

  case status {
    s if s >= 500 -> log.error(logger, message, context)
    s if s >= 400 -> log.warning(logger, message, context)
    _ -> log.info(logger, message, context)
  }
}

pub fn log_error(
  logger: Logger,
  request: HttpRequest,
  error_msg: String,
  request_id: String,
  duration_ms: Float,
) -> Nil {
  let method = request.method(request)
  let url = request.url(request)
  let path = get_path(url)

  log.error(logger, method <> " " <> path <> " failed: " <> error_msg, [
    #("request_id", json.string(request_id)),
    #("method", json.string(method)),
    #("path", json.string(path)),
    #("error", json.string(error_msg)),
    #("duration_ms", json.float(duration_ms)),
  ])
}

// FFI imports

@external(javascript, "../gflare_ffi_log.mjs", "get_current_time")
fn get_current_time() -> Float

// Internal helpers

fn get_path(url: String) -> String {
  case string.split(url, "?") {
    [path, _] -> path
    [path] -> path
    _ -> url
  }
}

fn response_status(response: Response) -> Int {
  do_response_status(response)
}

fn response_body(response: Response) -> Option(String) {
  do_response_body(response)
}

@external(javascript, "../gflare_ffi_log.mjs", "response_status")
fn do_response_status(response: Response) -> Int

@external(javascript, "../gflare_ffi_log.mjs", "response_body_text")
fn do_response_body(response: Response) -> Option(String)

fn int_to_string(n: Int) -> String {
  case n {
    0 -> "0"
    1 -> "1"
    2 -> "2"
    3 -> "3"
    4 -> "4"
    5 -> "5"
    6 -> "6"
    7 -> "7"
    8 -> "8"
    9 -> "9"
    _ -> {
      let digit = n % 10
      let rest = n / 10
      int_to_string(rest) <> int_to_string(digit)
    }
  }
}

fn float_to_string(f: Float) -> String {
  string.inspect(f)
}
