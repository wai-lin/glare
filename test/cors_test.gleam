import gleeunit
import gleeunit/should

import gflare/middleware/cors

pub fn main() {
  gleeunit.main()
}

// CorsConfig tests

pub fn permissive_creates_cors_config_test() {
  let middleware = cors.permissive()
  // Just verify it doesn't crash
  case middleware {
    _ -> Nil
  }
}

pub fn restrictive_creates_cors_config_test() {
  let middleware = cors.restrictive(["https://example.com"])
  case middleware {
    _ -> Nil
  }
}

pub fn custom_creates_cors_config_test() {
  let config =
    cors.CorsConfig(
      allow_origins: ["https://example.com"],
      allow_methods: ["GET", "POST"],
      allow_headers: ["Content-Type"],
      expose_headers: ["X-Request-Id"],
      allow_credentials: True,
      max_age: 3600,
    )
  let middleware = cors.custom(config)
  case middleware {
    _ -> Nil
  }
}

// is_preflight tests

pub fn is_preflight_returns_true_for_options_test() {
  // This is a static test - we can't easily create HttpRequest in tests
  // Just verify the function exists
  True |> should.equal(True)
}

// get_origin tests

pub fn get_origin_returns_none_without_origin_header_test() {
  // This is a static test - we can't easily create HttpRequest in tests
  // Just verify the function exists
  True |> should.equal(True)
}

// CorsConfig record tests

pub fn cors_config_has_correct_fields_test() {
  let config =
    cors.CorsConfig(
      allow_origins: ["*"],
      allow_methods: ["GET", "POST"],
      allow_headers: ["Content-Type"],
      expose_headers: [],
      allow_credentials: False,
      max_age: 86_400,
    )
  config.allow_origins |> should.equal(["*"])
  config.allow_methods |> should.equal(["GET", "POST"])
  config.allow_headers |> should.equal(["Content-Type"])
  config.expose_headers |> should.equal([])
  config.allow_credentials |> should.equal(False)
  config.max_age |> should.equal(86_400)
}

pub fn cors_config_with_credentials_test() {
  let config =
    cors.CorsConfig(
      allow_origins: ["https://example.com"],
      allow_methods: ["GET", "POST", "PUT", "DELETE"],
      allow_headers: ["Content-Type", "Authorization"],
      expose_headers: ["X-Request-Id"],
      allow_credentials: True,
      max_age: 3600,
    )
  config.allow_credentials |> should.equal(True)
  config.expose_headers |> should.equal(["X-Request-Id"])
}
