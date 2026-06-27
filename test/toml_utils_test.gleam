import gleeunit
import gleeunit/should

import gflare/cli/toml_utils
import gleam/dict
import gleam/list
import gleam/option.{None, Some}

pub fn main() {
  gleeunit.main()
}

pub fn parse_minimal_config_test() {
  let toml = "name = \"my-app\"\n"
  let result = toml_utils.parse_wrangler(toml)
  case result {
    Ok(config) -> {
      config.worker_name
      |> should.equal("my-app")
      config.compatibility_date
      |> should.equal("")
      config.bindings.kv
      |> should.equal([])
      config.bindings.d1
      |> should.equal([])
      config.bindings.r2
      |> should.equal([])
      config.durable_objects.classes
      |> should.equal([])
      config.vars
      |> should.equal(dict.new())
    }
    Error(_) -> should.fail()
  }
}

pub fn parse_config_with_compatibility_date_test() {
  let toml = "name = \"my-app\"\n" <> "compatibility_date = \"2025-01-01\"\n"
  case toml_utils.parse_wrangler(toml) {
    Ok(config) ->
      config.compatibility_date
      |> should.equal("2025-01-01")
    Error(_) -> should.fail()
  }
}

pub fn parse_config_with_kv_bindings_test() {
  let toml =
    "name = \"my-app\"\n"
    <> "\n"
    <> "[[kv_namespaces]]\n"
    <> "binding = \"CACHE\"\n"
    <> "\n"
    <> "[[kv_namespaces]]\n"
    <> "binding = \"SESSIONS\"\n"
  case toml_utils.parse_wrangler(toml) {
    Ok(config) ->
      config.bindings.kv
      |> should.equal(["CACHE", "SESSIONS"])
    Error(_) -> should.fail()
  }
}

pub fn parse_config_with_d1_bindings_test() {
  let toml =
    "name = \"my-app\"\n"
    <> "\n"
    <> "[[d1_databases]]\n"
    <> "binding = \"DB\"\n"
  case toml_utils.parse_wrangler(toml) {
    Ok(config) -> {
      config.bindings.d1
      |> list.length
      |> should.equal(1)
      case config.bindings.d1 {
        [d1] -> {
          d1.binding |> should.equal("DB")
          d1.database_name |> should.equal(None)
          d1.database_id |> should.equal(None)
          d1.migrations_dir |> should.equal(None)
        }
        _ -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}

pub fn parse_config_with_d1_full_bindings_test() {
  let toml =
    "name = \"my-app\"\n"
    <> "\n"
    <> "[[d1_databases]]\n"
    <> "binding = \"DB\"\n"
    <> "database_name = \"my-db\"\n"
    <> "database_id = \"abc-123\"\n"
    <> "migrations_dir = \"./db/migrations\"\n"
  case toml_utils.parse_wrangler(toml) {
    Ok(config) -> {
      config.bindings.d1
      |> list.length
      |> should.equal(1)
      case config.bindings.d1 {
        [d1] -> {
          d1.binding |> should.equal("DB")
          d1.database_name |> should.equal(Some("my-db"))
          d1.database_id |> should.equal(Some("abc-123"))
          d1.migrations_dir |> should.equal(Some("./db/migrations"))
        }
        _ -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}

pub fn parse_config_with_multiple_d1_bindings_test() {
  let toml =
    "name = \"my-app\"\n"
    <> "\n"
    <> "[[d1_databases]]\n"
    <> "binding = \"DB\"\n"
    <> "database_name = \"my-db\"\n"
    <> "\n"
    <> "[[d1_databases]]\n"
    <> "binding = \"DB_REPLICA\"\n"
    <> "database_id = \"xyz-789\"\n"
  case toml_utils.parse_wrangler(toml) {
    Ok(config) -> {
      config.bindings.d1
      |> list.length
      |> should.equal(2)
    }
    Error(_) -> should.fail()
  }
}

pub fn parse_config_with_r2_bindings_test() {
  let toml =
    "name = \"my-app\"\n"
    <> "\n"
    <> "[[r2_buckets]]\n"
    <> "binding = \"ASSETS\"\n"
    <> "\n"
    <> "[[r2_buckets]]\n"
    <> "binding = \"BACKUPS\"\n"
  case toml_utils.parse_wrangler(toml) {
    Ok(config) ->
      config.bindings.r2
      |> should.equal(["ASSETS", "BACKUPS"])
    Error(_) -> should.fail()
  }
}

pub fn parse_config_with_queue_bindings_test() {
  let toml =
    "name = \"my-app\"\n"
    <> "\n"
    <> "[queues]\n"
    <> "\n"
    <> "[[queues.producers]]\n"
    <> "binding = \"EVENTS\"\n"
    <> "\n"
    <> "[[queues.consumers]]\n"
    <> "queue = \"events\"\n"
  case toml_utils.parse_wrangler(toml) {
    Ok(config) -> {
      config.bindings.queues_producers
      |> should.equal(["EVENTS"])
      config.bindings.queues_consumers
      |> should.equal(["events"])
    }
    Error(_) -> should.fail()
  }
}

pub fn parse_config_with_vars_test() {
  let toml =
    "name = \"my-app\"\n"
    <> "\n"
    <> "[vars]\n"
    <> "ENVIRONMENT = \"production\"\n"
    <> "DEBUG = \"false\"\n"
  case toml_utils.parse_wrangler(toml) {
    Ok(config) -> {
      config.vars
      |> dict.get("ENVIRONMENT")
      |> should.equal(Ok("production"))
      config.vars
      |> dict.get("DEBUG")
      |> should.equal(Ok("false"))
    }
    Error(_) -> should.fail()
  }
}

pub fn parse_config_with_durable_objects_test() {
  let toml =
    "name = \"my-app\"\n"
    <> "\n"
    <> "[durable_objects]\n"
    <> "\n"
    <> "[[durable_objects.bindings]]\n"
    <> "name = \"Counter\"\n"
    <> "class_name = \"CounterDO\"\n"
    <> "\n"
    <> "[[durable_objects.bindings]]\n"
    <> "name = \"ChatRoom\"\n"
    <> "class_name = \"ChatRoomDO\"\n"
  case toml_utils.parse_wrangler(toml) {
    Ok(config) -> {
      config.durable_objects.classes
      |> list.length
      |> should.equal(2)
      case config.durable_objects.classes {
        [first, second, ..] -> {
          first.name |> should.equal("Counter")
          first.class_name |> should.equal("CounterDO")
          second.name |> should.equal("ChatRoom")
          second.class_name |> should.equal("ChatRoomDO")
        }
        _ -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}

pub fn parse_config_missing_name_test() {
  let toml = "compatibility_date = \"2025-01-01\"\n"
  toml_utils.parse_wrangler(toml)
  |> should.be_error
}

pub fn parse_config_invalid_toml_test() {
  let toml = "this is not valid toml {{{"
  toml_utils.parse_wrangler(toml)
  |> should.be_error
}

pub fn parse_empty_config_test() {
  toml_utils.parse_wrangler("")
  |> should.be_error
}
