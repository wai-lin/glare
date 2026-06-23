# Form Data

Parse multipart and URL-encoded form data from HTTP requests.

## Quick Start

```gleam
import gflare/form_data
import gflare/response

pub fn handle_upload(request, env, ctx, _params) {
  use result <- promise.await(form_data.parse(request))
  case result {
    Ok(fd) -> {
      let name = form_data.get_text(fd, "username")
      let avatar = form_data.get(fd, "avatar")
      // ...
    }
    Error(err) -> response.bad_request(err)
  }
}
```

## Parsing

```gleam
use result <- promise.await(form_data.parse(request))
// result: Result(FormData, String)
```

Parses `multipart/form-data` and `application/x-www-form-urlencoded` bodies using the browser's native `FormData` API.

## Accessing Fields

```gleam
// Get first value for a key
let name = form_data.get(fd, "name")
// -> Option(FormField)

// Get first value as text (convenience)
let name = form_data.get_text(fd, "name")
// -> Option(String)

// Get all values for a key (e.g. checkboxes)
let tags = form_data.get_all(fd, "tags")
// -> List(FormField)

// Get all entries
let entries = form_data.entries(fd)
// -> List(#(String, FormField))
```

## FormField Type

```gleam
pub type FormField {
  Text(value: String)
  File(filename: Option(String), content_type: Option(String), data: BitArray)
}
```

Text fields are `Text("value")`. File uploads are `File(filename, content_type, data)`.

## File Upload Example

```gleam
case form_data.get(fd, "avatar") {
  Some(form_data.File(filename, content_type, data)) -> {
    // filename: Some("photo.jpg")
    // content_type: Some("image/jpeg")
    // data: <<255, 216, 255, ...>>
    // Save to R2, etc.
  }
  Some(form_data.Text(_)) -> // Not a file
  None -> // No field found
}
```

## API Reference

```gleam
pub fn parse(request: Dynamic) -> Promise(Result(FormData, String))
pub fn get(fd: FormData, name: String) -> Option(FormField)
pub fn get_text(fd: FormData, name: String) -> Option(String)
pub fn get_all(fd: FormData, name: String) -> List(FormField)
pub fn entries(fd: FormData) -> List(#(String, FormField))
```
