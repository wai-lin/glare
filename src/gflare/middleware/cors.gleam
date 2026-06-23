import gflare/request.{type HttpRequest}
import gflare/response.{type Response}
import gflare/router.{type Middleware}
import gleam/int
import gleam/javascript/promise
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

pub type CorsConfig {
  CorsConfig(
    allow_origins: List(String),
    allow_methods: List(String),
    allow_headers: List(String),
    expose_headers: List(String),
    allow_credentials: Bool,
    max_age: Int,
  )
}

// Middleware constructor

pub fn middleware(config: CorsConfig) -> Middleware {
  router.Middleware(fn(req, env, ctx, next) {
    let origin = get_origin(req)

    // Handle preflight
    case is_preflight(req) {
      True -> {
        let response = response.no_content()
        case origin {
          Some(o) -> add_cors_headers(response, o, config)
          None -> response
        }
        |> promise.resolve
      }
      False -> {
        // Continue to handler
        let router.Handler(handler_fn) = next
        use resp <- promise.await(handler_fn(
          req,
          env,
          ctx,
          router.RouteParams([]),
        ))

        // Add CORS headers to response
        case origin {
          Some(o) -> add_cors_headers(resp, o, config)
          None -> resp
        }
        |> promise.resolve
      }
    }
  })
}

// Presets

pub fn permissive() -> Middleware {
  middleware(CorsConfig(
    allow_origins: ["*"],
    allow_methods: ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
    allow_headers: ["Content-Type", "Authorization", "X-Requested-With"],
    expose_headers: [],
    allow_credentials: False,
    max_age: 86_400,
  ))
}

pub fn restrictive(origins: List(String)) -> Middleware {
  middleware(CorsConfig(
    allow_origins: origins,
    allow_methods: ["GET", "POST", "PUT", "DELETE"],
    allow_headers: ["Content-Type", "Authorization"],
    expose_headers: [],
    allow_credentials: False,
    max_age: 3600,
  ))
}

pub fn custom(config: CorsConfig) -> Middleware {
  middleware(config)
}

// Helpers

pub fn set_cors_headers(
  resp: Response,
  origin: String,
  config: CorsConfig,
) -> Response {
  add_cors_headers(resp, origin, config)
}

pub fn is_preflight(request: HttpRequest) -> Bool {
  request.method(request) == "OPTIONS"
  && has_header(request, "access-control-request-method")
}

fn has_header(request: HttpRequest, name: String) -> Bool {
  let headers = request.headers(request)
  list.any(headers, fn(h) { h.0 == name })
}

pub fn get_origin(request: HttpRequest) -> Option(String) {
  let headers = request.headers(request)
  case list.find(headers, fn(h) { h.0 == "origin" }) {
    Ok(#(_, origin)) -> Some(origin)
    Error(_) -> None
  }
}

// Internal functions

fn add_cors_headers(
  resp: Response,
  origin: String,
  config: CorsConfig,
) -> Response {
  let is_allowed = case config.allow_origins {
    ["*"] -> True
    origins -> list.contains(origins, origin)
  }

  case is_allowed {
    True -> {
      let r =
        resp
        |> response.set_header("Access-Control-Allow-Origin", origin)
        |> response.set_header(
          "Access-Control-Allow-Methods",
          string.join(config.allow_methods, ", "),
        )
        |> response.set_header(
          "Access-Control-Allow-Headers",
          string.join(config.allow_headers, ", "),
        )
        |> response.set_header(
          "Access-Control-Max-Age",
          int.to_string(config.max_age),
        )

      let r = case config.allow_credentials {
        True ->
          r |> response.set_header("Access-Control-Allow-Credentials", "true")
        False -> r
      }

      case config.expose_headers {
        [] -> r
        _ ->
          r
          |> response.set_header(
            "Access-Control-Expose-Headers",
            string.join(config.expose_headers, ", "),
          )
      }
    }
    False -> resp
  }
}
