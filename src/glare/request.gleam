import gleam/dynamic.{type Dynamic}
import gleam/javascript/promise.{type Promise}

pub type HttpRequest

@external(javascript, "glare_ffi_worker.mjs", "request_url")
pub fn url(request: HttpRequest) -> String

@external(javascript, "glare_ffi_worker.mjs", "request_method")
pub fn method(request: HttpRequest) -> String

@external(javascript, "glare_ffi_worker.mjs", "request_headers")
pub fn headers(request: HttpRequest) -> List(#(String, String))

@external(javascript, "glare_ffi_worker.mjs", "request_body")
pub fn body(request: HttpRequest) -> Dynamic

@external(javascript, "glare_ffi_worker.mjs", "request_text")
pub fn text(request: HttpRequest) -> Promise(Result(String, String))

@external(javascript, "glare_ffi_worker.mjs", "request_json")
pub fn json(request: HttpRequest) -> Promise(Result(Dynamic, String))

@external(javascript, "glare_ffi_worker.mjs", "request_array_buffer")
pub fn array_buffer(request: HttpRequest) -> Promise(Result(BitArray, String))
