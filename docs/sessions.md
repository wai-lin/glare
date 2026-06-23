# Sessions

KV-backed session middleware for Cloudflare Workers.

## Quick Start

```gleam
import gflare/session
import gflare/router

pub fn fetch(request, env, ctx) {
  let session_config = session.default_config("SESSIONS")

  let routes = router.new()
  |> router.with_middleware(session.middleware(session_config))
  |> router.get("/login", login)
  |> router.get("/dashboard", dashboard)

  router.serve(routes, request, env, ctx)
}
```

## Handler Usage

### Reading Session Data

```gleam
pub fn dashboard(req, env, ctx, _params) {
  case session.get(req) {
    Ok(s) -> {
      case session.get_value(s, "user_id") {
        Some(uid) -> response.ok_text("Welcome " <> uid) |> promise.resolve
        None -> response.redirect("/login", 302) |> promise.resolve
      }
    }
    Error(_) -> response.redirect("/login", 302) |> promise.resolve
  }
}
```

### Modifying Session Data

```gleam
pub fn login(req, env, ctx, _params) {
  let assert Ok(s) = session.get(req)
  let updated = s
  |> session.set_value("user_id", "42")
  |> session.set_value("role", "admin")

  response.ok_text("Logged in")
  |> session.save(updated)  // Persist changes
  |> promise.resolve
}
```

### Removing Session Data

```gleam
pub fn logout(req, env, ctx, _params) {
  let assert Ok(s) = session.get(req)
  let updated = session.remove_value(s, "user_id")

  response.redirect("/", 302)
  |> session.save(updated)
  |> promise.resolve
}
```

## Configuration

```gleam
pub fn default_config(kv_name: String) -> SessionConfig {
  SessionConfig(
    cookie_name: "sid",      // Cookie name
    kv_name:,                // KV binding name in wrangler.toml
    ttl: 86_400,             // 24 hours
    secure: True,            // HTTPS only
    same_site: cookie.Lax,   // CSRF protection
  )
}
```

### Custom Config

```gleam
let config = session.SessionConfig(
  cookie_name: "my_session",
  kv_name: "SESSIONS",
  ttl: 3600,  // 1 hour
  secure: True,
  same_site: cookie.Strict,
)
```

## How It Works

1. **Request arrives**: Middleware reads the session cookie
2. **Session loaded**: If cookie exists, loads data from KV (`session:<id>`)
3. **New session**: If no cookie or KV miss, generates a new session ID
4. **Request enriched**: Session data is attached to the request (via internal header)
5. **Handler runs**: Calls `session.get(req)` to access session data
6. **Handler saves**: Calls `session.save(resp, updated_data)` to mark for saving
7. **Middleware saves**: Writes session to KV with TTL, sets cookie on response
8. **Cookie refresh**: Cookie is always set (refreshes TTL on every request)

## KV Storage

Sessions are stored in Cloudflare KV with the key format `session:<id>`.

The value is a JSON object:
```json
{
  "id": "uuid-here",
  "data": {
    "user_id": "42",
    "role": "admin"
  }
}
```

## wrangler.toml Setup

```toml
[[kv_namespaces]]
binding = "SESSIONS"
id = "your-kv-namespace-id"
```

## API Reference

```gleam
pub fn middleware(config: SessionConfig) -> router.Middleware
pub fn get(request: HttpRequest) -> Result(SessionData, String)
pub fn save(response: Response, session: SessionData) -> Response
pub fn set_value(session: SessionData, key: String, value: String) -> SessionData
pub fn get_value(session: SessionData, key: String) -> Option(String)
pub fn remove_value(session: SessionData, key: String) -> SessionData
pub fn default_config(kv_name: String) -> SessionConfig
```
