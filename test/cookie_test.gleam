import gleeunit
import gleeunit/should

import gflare/cookie
import gleam/option.{None, Some}

pub fn main() {
  gleeunit.main()
}

// SetCookieOptions tests

pub fn default_options_test() {
  let opts = cookie.default_options()
  opts.path |> should.equal(Some("/"))
  opts.secure |> should.equal(True)
  opts.http_only |> should.equal(True)
  opts.same_site |> should.equal(Some(cookie.Lax))
  opts.domain |> should.equal(None)
  opts.max_age |> should.equal(None)
}

pub fn set_domain_test() {
  let opts = cookie.default_options() |> cookie.set_domain("example.com")
  opts.domain |> should.equal(Some("example.com"))
}

pub fn set_path_test() {
  let opts = cookie.default_options() |> cookie.set_path("/api")
  opts.path |> should.equal(Some("/api"))
}

pub fn set_max_age_test() {
  let opts = cookie.default_options() |> cookie.set_max_age(3600)
  opts.max_age |> should.equal(Some(3600))
}

pub fn set_secure_test() {
  let opts = cookie.default_options() |> cookie.set_secure(False)
  opts.secure |> should.equal(False)
}

pub fn set_http_only_test() {
  let opts = cookie.default_options() |> cookie.set_http_only(False)
  opts.http_only |> should.equal(False)
}

pub fn set_same_site_strict_test() {
  let opts = cookie.default_options() |> cookie.set_same_site(cookie.Strict)
  opts.same_site |> should.equal(Some(cookie.Strict))
}

pub fn set_same_site_none_test() {
  let opts = cookie.default_options() |> cookie.set_same_site(cookie.NoneMode)
  opts.same_site |> should.equal(Some(cookie.NoneMode))
}

// SameSite variants

pub fn same_site_variants_test() {
  cookie.Strict |> should.equal(cookie.Strict)
  cookie.Lax |> should.equal(cookie.Lax)
  cookie.NoneMode |> should.equal(cookie.NoneMode)
}
