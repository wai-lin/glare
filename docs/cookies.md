# Cookies

HTTP cookie parsing and setting for gflare.

## Quick Start

```gleam
import gflare/cookie
import gflare/response

// Read a cookie from request
let token = cookie.get(request, "auth_token")

// Set a cookie on response
let resp = response.ok_text("Done")
|> cookie.set("auth_token", "abc123", cookie.default_options())

// Delete a cookie
let resp = cookie.delete(resp, "auth_token")
```

## Reading Cookies

```gleam
// Get a single cookie by name
let value = cookie.get(request, "session_id")
// -> Option(String)

// Parse all cookies
let all = cookie.parse(request)
// -> Result(List(#(String, String)), String)
```

## Setting Cookies

```gleam
let opts = cookie.default_options()
|> cookie.set_max_age(3600)        // 1 hour
|> cookie.set_http_only(True)       // not accessible via JS
|> cookie.set_secure(True)          // HTTPS only
|> cookie.set_same_site(cookie.Lax) // CSRF protection

let resp = response.ok_text("OK")
|> cookie.set("session_id", "xyz789", opts)
```

## Options

`SetCookieOptions` fields:

| Field | Type | Default |
|-------|------|---------|
| `domain` | `Option(String)` | `None` |
| `path` | `Option(String)` | `Some("/")` |
| `max_age` | `Option(Int)` | `None` |
| `secure` | `Bool` | `True` |
| `http_only` | `Bool` | `True` |
| `same_site` | `Option(SameSite)` | `Some(Lax)` |

## SameSite

```gleam
cookie.Strict   // Cookie only sent with same-site requests
cookie.Lax      // Cookie sent with top-level navigations (recommended)
cookie.None     // Cookie sent with all requests (requires Secure)
```

## Deleting Cookies

```gleam
let resp = cookie.delete(resp, "auth_token")
// Sets the cookie with Max-Age=0 to expire it
```

## API Reference

```gleam
pub fn get(request: HttpRequest, name: String) -> Option(String)
pub fn parse(request: HttpRequest) -> Result(List(#(String, String)), String)
pub fn set(response: Response, name: String, value: String, options: SetCookieOptions) -> Response
pub fn delete(response: Response, name: String) -> Response
pub fn default_options() -> SetCookieOptions
pub fn set_domain(options: SetCookieOptions, domain: String) -> SetCookieOptions
pub fn set_path(options: SetCookieOptions, path: String) -> SetCookieOptions
pub fn set_max_age(options: SetCookieOptions, max_age: Int) -> SetCookieOptions
pub fn set_secure(options: SetCookieOptions, secure: Bool) -> SetCookieOptions
pub fn set_http_only(options: SetCookieOptions, http_only: Bool) -> SetCookieOptions
pub fn set_same_site(options: SetCookieOptions, same_site: SameSite) -> SetCookieOptions
```
