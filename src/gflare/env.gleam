import gleam/javascript/promise.{type Promise}
import gleam/option.{type Option}

@external(javascript, "../gflare_ffi_env.mjs", "get_env_option")
pub fn get(name: String) -> Option(String)

@external(javascript, "../gflare_ffi_env.mjs", "get_env_or")
pub fn get_or(name: String, default: String) -> String

/// Block on a promise synchronously. Internal use only.
@external(javascript, "../gflare_ffi_env.mjs", "block_on_promise")
pub fn block_on(promise: Promise(a)) -> a
