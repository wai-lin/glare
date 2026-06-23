import gleam/dynamic.{type Dynamic}
import gleam/javascript/promise
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result

pub type FormField {
  Text(value: String)
  File(filename: Option(String), content_type: Option(String), data: BitArray)
}

pub opaque type FormData {
  FormData(entries: List(#(String, FormField)))
}

// ponytail: FormData is constructed by FFI (gflare_ffi_form_data.mjs)
// The constructor is used by the FFI but Gleam reports it as unused

// FFI

@external(javascript, "../gflare_ffi_form_data.mjs", "parse_form_data")
fn do_parse(request: Dynamic) -> promise.Promise(Result(FormData, String))

// Public API

pub fn parse(
  request: Dynamic,
) -> promise.Promise(Result(FormData, String)) {
  do_parse(request)
}

pub fn get(fd: FormData, name: String) -> Option(FormField) {
  list.find(fd.entries, fn(e) { e.0 == name })
  |> result.map(fn(pair) { pair.1 })
  |> option.from_result
}

pub fn get_text(fd: FormData, name: String) -> Option(String) {
  case get(fd, name) {
    Some(Text(value)) -> Some(value)
    _ -> None
  }
}

pub fn get_all(fd: FormData, name: String) -> List(FormField) {
  fd.entries
  |> list.filter(fn(e) { e.0 == name })
  |> list.map(fn(e) { e.1 })
}

pub fn entries(fd: FormData) -> List(#(String, FormField)) {
  fd.entries
}
