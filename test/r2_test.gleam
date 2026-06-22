import gleeunit
import gleeunit/should

import gflare/r2
import gleam/list
import gleam/option.{None, Some}

pub fn main() {
  gleeunit.main()
}

// PutOptions tests

pub fn put_options_default_test() {
  let opts = r2.put_options()
  opts.http_metadata |> should.equal(None)
  opts.custom_metadata |> should.equal(None)
}

pub fn put_options_with_http_metadata_test() {
  let meta =
    r2.HttpMetadata(
      content_type: Some("text/plain"),
      content_disposition: None,
      content_encoding: None,
      cache_control: None,
      cache_expiry: None,
    )
  let opts =
    r2.put_options_with(http_metadata: Some(meta), custom_metadata: None)
  opts.http_metadata |> should.be_some
  opts.custom_metadata |> should.equal(None)
}

pub fn put_options_with_custom_metadata_test() {
  let meta = [#("key", "value")]
  let opts =
    r2.put_options_with(http_metadata: None, custom_metadata: Some(meta))
  opts.http_metadata |> should.equal(None)
  opts.custom_metadata |> should.be_some
}

pub fn put_options_with_all_test() {
  let meta =
    r2.HttpMetadata(
      content_type: Some("application/json"),
      content_disposition: Some("attachment"),
      content_encoding: Some("gzip"),
      cache_control: Some("max-age=3600"),
      cache_expiry: Some(1_700_000_000),
    )
  let custom = [#("author", "alice")]
  let opts =
    r2.put_options_with(
      http_metadata: Some(meta),
      custom_metadata: Some(custom),
    )
  opts.http_metadata |> should.be_some
  opts.custom_metadata |> should.be_some
}

// HttpMetadata tests

pub fn http_metadata_construction_test() {
  let meta =
    r2.HttpMetadata(
      content_type: Some("text/html"),
      content_disposition: None,
      content_encoding: None,
      cache_control: None,
      cache_expiry: None,
    )
  meta.content_type |> should.equal(Some("text/html"))
  meta.content_disposition |> should.equal(None)
}

pub fn http_metadata_all_fields_test() {
  let meta =
    r2.HttpMetadata(
      content_type: Some("image/png"),
      content_disposition: Some("inline"),
      content_encoding: Some("br"),
      cache_control: Some("public, max-age=86400"),
      cache_expiry: Some(1_700_000_000),
    )
  meta.content_type |> should.equal(Some("image/png"))
  meta.content_disposition |> should.equal(Some("inline"))
  meta.content_encoding |> should.equal(Some("br"))
  meta.cache_control |> should.equal(Some("public, max-age=86400"))
  meta.cache_expiry |> should.equal(Some(1_700_000_000))
}

pub fn http_metadata_equality_test() {
  let meta1 =
    r2.HttpMetadata(
      content_type: Some("text/plain"),
      content_disposition: None,
      content_encoding: None,
      cache_control: None,
      cache_expiry: None,
    )
  let meta2 =
    r2.HttpMetadata(
      content_type: Some("text/plain"),
      content_disposition: None,
      content_encoding: None,
      cache_control: None,
      cache_expiry: None,
    )
  meta1 |> should.equal(meta2)
}

// ListOptions tests

pub fn list_options_default_test() {
  let opts = r2.list_options()
  opts.prefix |> should.equal(None)
  opts.cursor |> should.equal(None)
  opts.delimiter |> should.equal(None)
  opts.limit |> should.equal(None)
  opts.include |> should.equal(None)
}

pub fn list_options_with_prefix_test() {
  let opts =
    r2.ListOptions(
      prefix: Some("uploads/"),
      cursor: None,
      delimiter: None,
      limit: None,
      include: None,
    )
  opts.prefix |> should.equal(Some("uploads/"))
}

pub fn list_options_with_all_test() {
  let opts =
    r2.ListOptions(
      prefix: Some("files/"),
      cursor: Some("token123"),
      delimiter: Some("/"),
      limit: Some(50),
      include: Some(["httpMetadata", "customMetadata"]),
    )
  opts.prefix |> should.equal(Some("files/"))
  opts.cursor |> should.equal(Some("token123"))
  opts.delimiter |> should.equal(Some("/"))
  opts.limit |> should.equal(Some(50))
  opts.include |> should.equal(Some(["httpMetadata", "customMetadata"]))
}

// ListObject tests

pub fn list_object_construction_test() {
  let obj =
    r2.ListObject(
      key: "file.txt",
      version: "abc123",
      size: 1024,
      etag: "etag456",
      uploaded: "2024-01-15T10:00:00Z",
    )
  obj.key |> should.equal("file.txt")
  obj.version |> should.equal("abc123")
  obj.size |> should.equal(1024)
  obj.etag |> should.equal("etag456")
  obj.uploaded |> should.equal("2024-01-15T10:00:00Z")
}

// R2ObjectResult tests

pub fn r2_object_result_construction_test() {
  let result =
    r2.R2ObjectResult(
      key: "test.txt",
      version: "v1",
      size: 512,
      etag: "etag789",
      uploaded: "2024-01-15T12:00:00Z",
    )
  result.key |> should.equal("test.txt")
  result.size |> should.equal(512)
}

pub fn r2_object_result_equality_test() {
  let r1 =
    r2.R2ObjectResult(
      key: "a.txt",
      version: "v1",
      size: 100,
      etag: "e1",
      uploaded: "2024-01-01",
    )
  let r2_obj =
    r2.R2ObjectResult(
      key: "a.txt",
      version: "v1",
      size: 100,
      etag: "e1",
      uploaded: "2024-01-01",
    )
  r1 |> should.equal(r2_obj)
}

// ListResult tests

pub fn list_result_empty_test() {
  let result =
    r2.ListResult(
      objects: [],
      truncated: True,
      cursor: None,
      delimited_prefixes: [],
    )
  result.objects |> should.equal([])
  result.truncated |> should.equal(True)
  result.cursor |> should.equal(None)
  result.delimited_prefixes |> should.equal([])
}

pub fn list_result_with_cursor_test() {
  let result =
    r2.ListResult(
      objects: [],
      truncated: False,
      cursor: Some("next_page"),
      delimited_prefixes: [],
    )
  result.truncated |> should.equal(False)
  result.cursor |> should.equal(Some("next_page"))
}

pub fn list_result_with_objects_test() {
  let objects = [
    r2.ListObject(
      key: "a.txt",
      version: "v1",
      size: 100,
      etag: "e1",
      uploaded: "2024-01-01",
    ),
    r2.ListObject(
      key: "b.txt",
      version: "v2",
      size: 200,
      etag: "e2",
      uploaded: "2024-01-02",
    ),
  ]
  let result =
    r2.ListResult(
      objects:,
      truncated: True,
      cursor: None,
      delimited_prefixes: [],
    )
  list.length(result.objects) |> should.equal(2)
}

pub fn list_result_with_delimited_prefixes_test() {
  let result =
    r2.ListResult(
      objects: [],
      truncated: True,
      cursor: None,
      delimited_prefixes: ["folder1/", "folder2/"],
    )
  result.delimited_prefixes |> should.equal(["folder1/", "folder2/"])
}

// Option encoding tests

pub fn option_to_json_some_test() {
  let opts =
    r2.put_options_with(
      http_metadata: Some(r2.HttpMetadata(
        content_type: Some("text/plain"),
        content_disposition: None,
        content_encoding: None,
        cache_control: None,
        cache_expiry: None,
      )),
      custom_metadata: None,
    )
  opts.http_metadata |> should.be_some
}

pub fn option_to_json_none_test() {
  let opts = r2.put_options()
  opts.http_metadata |> should.equal(None)
  opts.custom_metadata |> should.equal(None)
}
