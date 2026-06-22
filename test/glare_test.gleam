import gleeunit
import gleeunit/should

import glare
import gleam/list
import gleam/string

pub fn main() {
  gleeunit.main()
}

pub fn version_returns_1_0_0_test() {
  glare.version() |> should.equal("1.0.0")
}

pub fn version_is_semver_test() {
  let version = glare.version()
  let parts = string.split(version, ".")
  list.length(parts) |> should.equal(3)
}
