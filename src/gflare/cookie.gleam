import gflare/request.{type HttpRequest}
import gflare/response.{type Response}
import gleam/int
import gleam/list
import gleam/option.{type Option}
import gleam/string

pub type SameSite {
  Strict
  Lax
  NoneMode
}

pub type SetCookieOptions {
  SetCookieOptions(
    domain: Option(String),
    path: Option(String),
    max_age: Option(Int),
    secure: Bool,
    http_only: Bool,
    same_site: Option(SameSite),
  )
}

// Read cookies from request

pub fn get(request: HttpRequest, name: String) -> Option(String) {
  case parse(request) {
    Error(_) -> option.None
    Ok(cookies) ->
      case list.find(cookies, fn(c) { c.0 == name }) {
        Ok(#(_, value)) -> option.Some(value)
        Error(_) -> option.None
      }
  }
}

pub fn parse(
  request: HttpRequest,
) -> Result(List(#(String, String)), String) {
  let headers = request.headers(request)
  case list.find(headers, fn(h) { h.0 == "cookie" }) {
    Ok(#(_, cookie_header)) -> Ok(parse_cookie_header(cookie_header))
    Error(_) -> Ok([])
  }
}

// Set cookies on response

pub fn set(
  response: Response,
  name: String,
  value: String,
  options: SetCookieOptions,
) -> Response {
  let cookie_string = format_set_cookie(name, value, options)
  append_header(response, "set-cookie", cookie_string)
}

pub fn delete(response: Response, name: String) -> Response {
  set(response, name, "", default_options() |> set_max_age(0))
}

// Options

pub fn default_options() -> SetCookieOptions {
  SetCookieOptions(
    domain: option.None,
    path: option.Some("/"),
    max_age: option.None,
    secure: True,
    http_only: True,
    same_site: option.Some(Lax),
  )
}

pub fn set_domain(
  options: SetCookieOptions,
  domain: String,
) -> SetCookieOptions {
  SetCookieOptions(..options, domain: option.Some(domain))
}

pub fn set_path(options: SetCookieOptions, path: String) -> SetCookieOptions {
  SetCookieOptions(..options, path: option.Some(path))
}

pub fn set_max_age(
  options: SetCookieOptions,
  max_age: Int,
) -> SetCookieOptions {
  SetCookieOptions(..options, max_age: option.Some(max_age))
}

pub fn set_secure(options: SetCookieOptions, secure: Bool) -> SetCookieOptions {
  SetCookieOptions(..options, secure:)
}

pub fn set_http_only(
  options: SetCookieOptions,
  http_only: Bool,
) -> SetCookieOptions {
  SetCookieOptions(..options, http_only:)
}

pub fn set_same_site(
  options: SetCookieOptions,
  same_site: SameSite,
) -> SetCookieOptions {
  SetCookieOptions(..options, same_site: option.Some(same_site))
}

// Internal

fn parse_cookie_header(header: String) -> List(#(String, String)) {
  header
  |> string.split(";")
  |> list.map(string.trim)
  |> list.filter(fn(s) { s != "" })
  |> list.filter_map(fn(pair) {
    case string.split(pair, "=") {
      [name, ..rest] -> {
        let value = string.join(rest, "=")
        Ok(#(string.trim(name), string.trim(value)))
      }
      _ -> Error(Nil)
    }
  })
}

fn format_set_cookie(
  name: String,
  value: String,
  options: SetCookieOptions,
) -> String {
  let parts = [name <> "=" <> value]

  let parts = case options.domain {
    option.Some(d) -> list.append(parts, ["Domain=" <> d])
    option.None -> parts
  }

  let parts = case options.path {
    option.Some(p) -> list.append(parts, ["Path=" <> p])
    option.None -> parts
  }

  let parts = case options.max_age {
    option.Some(age) -> list.append(parts, ["Max-Age=" <> int.to_string(age)])
    option.None -> parts
  }

  let parts = case options.secure {
    True -> list.append(parts, ["Secure"])
    False -> parts
  }

  let parts = case options.http_only {
    True -> list.append(parts, ["HttpOnly"])
    False -> parts
  }

  let parts = case options.same_site {
    option.Some(Strict) -> list.append(parts, ["SameSite=Strict"])
    option.Some(Lax) -> list.append(parts, ["SameSite=Lax"])
    option.Some(NoneMode) -> list.append(parts, ["SameSite=None"])
    option.None -> parts
  }

  string.join(parts, "; ")
}

@external(javascript, "../gflare_ffi_worker.mjs", "append_header")
fn append_header(response: Response, name: String, value: String) -> Response
