import gleam/json.{type Json}

pub type Response

@external(javascript, "glare_ffi_worker.mjs", "new_response")
pub fn new(status: Int) -> Response

@external(javascript, "glare_ffi_worker.mjs", "set_body")
pub fn set_body(response: Response, body: String) -> Response

@external(javascript, "glare_ffi_worker.mjs", "set_header")
pub fn set_header(response: Response, name: String, value: String) -> Response

@external(javascript, "glare_ffi_worker.mjs", "response_json")
pub fn json(response: Response, data: Json) -> Response

@external(javascript, "glare_ffi_worker.mjs", "response_bytes")
pub fn bytes(response: Response, data: BitArray) -> Response

@external(javascript, "glare_ffi_worker.mjs", "response_empty")
pub fn empty(status: Int) -> Response

@external(javascript, "glare_ffi_worker.mjs", "redirect")
pub fn redirect(url: String, status: Int) -> Response
