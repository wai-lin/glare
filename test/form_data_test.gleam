import gleeunit
import gleeunit/should

import gflare/form_data
import gleam/option.{None, Some}

pub fn main() {
  gleeunit.main()
}

// FormField tests

pub fn text_field_test() {
  let field = form_data.Text("hello")
  case field {
    form_data.Text(value) -> value |> should.equal("hello")
    _ -> should.fail()
  }
}

pub fn file_field_test() {
  let field =
    form_data.File(
      filename: Some("photo.jpg"),
      content_type: Some("image/jpeg"),
      data: <<1, 2, 3>>,
    )
  case field {
    form_data.File(filename, content_type, data) -> {
      filename |> should.equal(Some("photo.jpg"))
      content_type |> should.equal(Some("image/jpeg"))
      data |> should.equal(<<1, 2, 3>>)
    }
    _ -> should.fail()
  }
}

pub fn file_field_no_filename_test() {
  let field =
    form_data.File(filename: None, content_type: Some("text/plain"), data: <<>>)
  case field {
    form_data.File(filename, _, _) -> filename |> should.equal(None)
    _ -> should.fail()
  }
}
