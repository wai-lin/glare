import gleeunit
import gleeunit/should

import gleam/dict
import glare/cli/toml_utils

pub fn main() {
  gleeunit.main()
}

pub fn parse_minimal_config_test() {
  let toml =
    "name = \"my_app\"\n"
    <> "\n"
    <> "[cloudflare]\n"
    <> "name = \"my-app\"\n"
  let result = toml_utils.parse_config(toml)
  case result {
    Ok(config) -> {
      config.package_name
      |> should.equal("my_app")
      config.cloudflare.name
      |> should.equal("my-app")
      config.cloudflare.compatibility_date
      |> should.equal("")
      config.cloudflare.bindings.kv
      |> should.equal([])
      config.cloudflare.bindings.d1
      |> should.equal([])
      config.cloudflare.bindings.r2
      |> should.equal([])
      config.cloudflare.durable_objects.classes
      |> should.equal([])
      config.cloudflare.vars
      |> should.equal(dict.new())
    }
    Error(_) -> should.fail()
  }
}

pub fn parse_config_with_compatibility_date_test() {
  let toml =
    "name = \"my_app\"\n"
    <> "\n"
    <> "[cloudflare]\n"
    <> "name = \"my-app\"\n"
    <> "compatibility_date = \"2025-01-01\"\n"
  case toml_utils.parse_config(toml) {
    Ok(config) ->
      config.cloudflare.compatibility_date
      |> should.equal("2025-01-01")
    Error(_) -> should.fail()
  }
}

pub fn parse_config_with_kv_bindings_test() {
  let toml =
    "name = \"my_app\"\n"
    <> "\n"
    <> "[cloudflare]\n"
    <> "name = \"my-app\"\n"
    <> "\n"
    <> "[cloudflare.bindings]\n"
    <> "kv = [\"CACHE\", \"SESSIONS\"]\n"
  case toml_utils.parse_config(toml) {
    Ok(config) ->
      config.cloudflare.bindings.kv
      |> should.equal(["CACHE", "SESSIONS"])
    Error(_) -> should.fail()
  }
}

pub fn parse_config_with_d1_bindings_test() {
  let toml =
    "name = \"my_app\"\n"
    <> "\n"
    <> "[cloudflare]\n"
    <> "name = \"my-app\"\n"
    <> "\n"
    <> "[cloudflare.bindings]\n"
    <> "d1 = [\"DB\"]\n"
  case toml_utils.parse_config(toml) {
    Ok(config) ->
      config.cloudflare.bindings.d1
      |> should.equal(["DB"])
    Error(_) -> should.fail()
  }
}

pub fn parse_config_with_r2_bindings_test() {
  let toml =
    "name = \"my_app\"\n"
    <> "\n"
    <> "[cloudflare]\n"
    <> "name = \"my-app\"\n"
    <> "\n"
    <> "[cloudflare.bindings]\n"
    <> "r2 = [\"ASSETS\", \"BACKUPS\"]\n"
  case toml_utils.parse_config(toml) {
    Ok(config) ->
      config.cloudflare.bindings.r2
      |> should.equal(["ASSETS", "BACKUPS"])
    Error(_) -> should.fail()
  }
}

pub fn parse_config_with_queue_bindings_test() {
  let toml =
    "name = \"my_app\"\n"
    <> "\n"
    <> "[cloudflare]\n"
    <> "name = \"my-app\"\n"
    <> "\n"
    <> "[cloudflare.bindings]\n"
    <> "queues_producers = [\"EVENTS\"]\n"
    <> "queues_consumers = [\"events\"]\n"
  case toml_utils.parse_config(toml) {
    Ok(config) -> {
      config.cloudflare.bindings.queues_producers
      |> should.equal(["EVENTS"])
      config.cloudflare.bindings.queues_consumers
      |> should.equal(["events"])
    }
    Error(_) -> should.fail()
  }
}

pub fn parse_config_with_vars_test() {
  let toml =
    "name = \"my_app\"\n"
    <> "\n"
    <> "[cloudflare]\n"
    <> "name = \"my-app\"\n"
    <> "\n"
    <> "[cloudflare.vars]\n"
    <> "ENVIRONMENT = \"production\"\n"
    <> "DEBUG = \"false\"\n"
  case toml_utils.parse_config(toml) {
    Ok(config) -> {
      config.cloudflare.vars
      |> dict.get("ENVIRONMENT")
      |> should.equal(Ok("production"))
      config.cloudflare.vars
      |> dict.get("DEBUG")
      |> should.equal(Ok("false"))
    }
    Error(_) -> should.fail()
  }
}

pub fn parse_config_missing_name_test() {
  let toml =
    "version = \"1.0.0\"\n"
    <> "\n"
    <> "[cloudflare]\n"
    <> "name = \"my-app\"\n"
  toml_utils.parse_config(toml)
  |> should.be_error
}

pub fn parse_config_missing_cloudflare_section_test() {
  let toml =
    "name = \"my_app\"\n"
    <> "version = \"1.0.0\"\n"
  toml_utils.parse_config(toml)
  |> should.be_error
}

pub fn parse_config_missing_cloudflare_name_test() {
  let toml =
    "name = \"my_app\"\n"
    <> "\n"
    <> "[cloudflare]\n"
    <> "compatibility_date = \"2025-01-01\"\n"
  toml_utils.parse_config(toml)
  |> should.be_error
}

pub fn parse_config_invalid_toml_test() {
  let toml = "this is not valid toml {{{"
  toml_utils.parse_config(toml)
  |> should.be_error
}

pub fn parse_empty_config_test() {
  toml_utils.parse_config("")
  |> should.be_error
}
