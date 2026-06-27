import gleeunit
import gleeunit/should

import gflare/cli/handlers
import gflare/cli/toml_utils
import gleam/int
import gleam/list
import gleam/option.{Some}
import gleam/string
import simplifile

pub fn main() {
  gleeunit.main()
}

fn test_dir_name(n: Int) -> String {
  "./test_tmp_build_" <> int.to_string(n)
}

pub fn detect_handlers_from_compiled_gleam_test() {
  let mjs =
    "import { fetch } from \"./gleam.mjs\";\n"
    <> "\n"
    <> "export function fetch(request, env, ctx) {\n"
    <> "  return new Response(\"Hello!\");\n"
    <> "}\n"
  handlers.detect_handlers(mjs)
  |> should.equal(["fetch"])
}

pub fn detect_handlers_from_multiple_exports_test() {
  let mjs =
    "export function fetch(request, env, ctx) {\n"
    <> "  return new Response(\"ok\");\n"
    <> "}\n"
    <> "\n"
    <> "export function queue(batch, env, ctx) {\n"
    <> "  batch.messages.forEach(m => m.ack());\n"
    <> "}\n"
    <> "\n"
    <> "export async function scheduled(event, env, ctx) {\n"
    <> "  console.log(\"tick\");\n"
    <> "}\n"
  let result = handlers.detect_handlers(mjs)
  list.length(result)
  |> should.equal(3)
  list.contains(result, "fetch")
  |> should.be_true
  list.contains(result, "queue")
  |> should.be_true
  list.contains(result, "scheduled")
  |> should.be_true
}

pub fn detect_handlers_from_complex_mjs_test() {
  let mjs =
    "import * as $option from \"../../gleam_stdlib/gleam/option.mjs\";\n"
    <> "import { Some, None } from \"../../gleam_stdlib/gleam/option.mjs\";\n"
    <> "import { KvError } from \"../gflare/error.mjs\";\n"
    <> "import { Ok, Error } from \"../gleam.mjs\";\n"
    <> "\n"
    <> "export function fetch(request, env, ctx) {\n"
    <> "  const cache = env[\"CACHE\"];\n"
    <> "  return cache.get(\"greeting\").then(value => {\n"
    <> "    if (value !== null) {\n"
    <> "      return new Response(value, { status: 200 });\n"
    <> "    }\n"
    <> "    return new Response(\"Hello!\", { status: 200 });\n"
    <> "  });\n"
    <> "}\n"
  handlers.detect_handlers(mjs)
  |> should.equal(["fetch"])
}

pub fn detect_handlers_no_false_positive_from_variable_names_test() {
  let mjs =
    "const fetchHandler = (req) => new Response(\"ok\");\n"
    <> "export default { fetch: fetchHandler };\n"
  handlers.detect_handlers(mjs)
  |> should.equal([])
}

pub fn detect_handlers_no_false_positive_from_object_keys_test() {
  let mjs =
    "export default {\n"
    <> "  fetch(request, env, ctx) {\n"
    <> "    return new Response(\"ok\");\n"
    <> "  },\n"
    <> "};\n"
  handlers.detect_handlers(mjs)
  |> should.equal([])
}

pub fn parse_realistic_wrangler_toml_test() {
  let toml =
    "name = \"my-worker\"\n"
    <> "compatibility_date = \"2025-01-01\"\n"
    <> "\n"
    <> "[[kv_namespaces]]\n"
    <> "binding = \"CACHE\"\n"
    <> "\n"
    <> "[[kv_namespaces]]\n"
    <> "binding = \"SESSIONS\"\n"
    <> "\n"
    <> "[[r2_buckets]]\n"
    <> "binding = \"ASSETS\"\n"
    <> "\n"
    <> "[queues]\n"
    <> "\n"
    <> "[[queues.producers]]\n"
    <> "binding = \"EVENTS\"\n"
    <> "\n"
    <> "[[queues.consumers]]\n"
    <> "queue = \"events\"\n"
    <> "\n"
    <> "[[d1_databases]]\n"
    <> "binding = \"DB\"\n"
    <> "database_name = \"my-db\"\n"
    <> "database_id = \"abc-123\"\n"
    <> "migrations_dir = \"./db/migrations\"\n"
    <> "\n"
    <> "[vars]\n"
    <> "ENVIRONMENT = \"production\"\n"

  case toml_utils.parse_wrangler(toml) {
    Ok(config) -> {
      config.worker_name |> should.equal("my-worker")
      config.compatibility_date |> should.equal("2025-01-01")
      config.bindings.kv |> should.equal(["CACHE", "SESSIONS"])
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
      config.bindings.r2 |> should.equal(["ASSETS"])
      config.bindings.queues_producers
      |> should.equal(["EVENTS"])
      config.bindings.queues_consumers
      |> should.equal(["events"])
    }
    Error(_) -> should.fail()
  }
}

pub fn parse_toml_with_durable_objects_test() {
  let toml =
    "name = \"my-worker\"\n"
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
      let classes = config.durable_objects.classes
      case classes {
        [first, ..] -> {
          first.name |> should.equal("Counter")
          first.class_name |> should.equal("CounterDO")
        }
        [] -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}

pub fn write_and_read_generated_entrypoint_test() {
  let dir = test_dir_name(1)
  let _ = simplifile.create_directory_all(dir)

  let entrypoint =
    "import * as handler from \"./my_worker.mjs\";\n"
    <> "\n"
    <> "const exports = {};\n"
    <> "\n"
    <> "  async fetch(...args) {\n"
    <> "    return handler.fetch(...args);\n"
    <> "  },\n"
    <> "\n"
    <> "export default exports;\n"

  let assert Ok(_) =
    simplifile.write(to: dir <> "/index.js", contents: entrypoint)

  let assert Ok(content) = simplifile.read(dir <> "/index.js")
  content
  |> string.contains("import * as handler from \"./my_worker.mjs\"")
  |> should.be_true
  content
  |> string.contains("export default exports")
  |> should.be_true

  let _ = simplifile.delete(dir)
}

pub fn write_and_read_generated_wrangler_test() {
  let dir = test_dir_name(2)
  let _ = simplifile.create_directory_all(dir)

  let wrangler =
    "name = \"my-worker\"\n"
    <> "main = \"./build/dist/bundle.js\"\n"
    <> "compatibility_date = \"2025-01-01\"\n"
    <> "\n"
    <> "[[kv_namespaces]]\n"
    <> "binding = \"CACHE\"\n"
    <> "id = \"abc-123\"\n"
    <> "\n"
    <> "[[d1_databases]]\n"
    <> "binding = \"DB\"\n"
    <> "database_name = \"my-worker-db\"\n"
    <> "database_id = \"xyz-789\"\n"

  let assert Ok(_) =
    simplifile.write(to: dir <> "/wrangler.toml", contents: wrangler)

  let assert Ok(content) = simplifile.read(dir <> "/wrangler.toml")
  content
  |> string.contains("name = \"my-worker\"")
  |> should.be_true
  content
  |> string.contains("[[kv_namespaces]]")
  |> should.be_true
  content
  |> string.contains("[[d1_databases]]")
  |> should.be_true

  let _ = simplifile.delete(dir)
}

pub fn full_pipeline_test() {
  let dir = test_dir_name(3)
  let _ = simplifile.create_directory_all(dir <> "/src")

  let wrangler_toml =
    "name = \"pipeline-test\"\n"
    <> "compatibility_date = \"2025-01-01\"\n"
    <> "\n"
    <> "[[kv_namespaces]]\n"
    <> "binding = \"CACHE\"\n"
    <> "\n"
    <> "[[d1_databases]]\n"
    <> "binding = \"DB\"\n"
    <> "database_name = \"pipeline-db\"\n"
  let assert Ok(_) =
    simplifile.write(to: dir <> "/wrangler.toml", contents: wrangler_toml)

  let assert Ok(content) = simplifile.read(dir <> "/wrangler.toml")
  let assert Ok(config) = toml_utils.parse_wrangler(content)

  config.worker_name |> should.equal("pipeline-test")
  config.compatibility_date |> should.equal("2025-01-01")
  config.bindings.kv |> should.equal(["CACHE"])
  config.bindings.d1
  |> list.length
  |> should.equal(1)
  case config.bindings.d1 {
    [d1] -> {
      d1.binding |> should.equal("DB")
      d1.database_name |> should.equal(Some("pipeline-db"))
    }
    _ -> should.fail()
  }

  let mjs =
    "export function fetch(request, env, ctx) {\n"
    <> "  return new Response(\"ok\");\n"
    <> "}\n"
    <> "\n"
    <> "export function queue(batch, env, ctx) {\n"
    <> "  batch.messages.forEach(m => m.ack());\n"
    <> "}\n"
  let detected = handlers.detect_handlers(mjs)
  list.contains(detected, "fetch")
  |> should.be_true
  list.contains(detected, "queue")
  |> should.be_true

  let entrypoint =
    "import * as handler from \"./"
    <> "pipeline_test"
    <> ".mjs\";\n"
    <> "export default { fetch: handler.fetch, queue: handler.queue };\n"
  let assert Ok(_) =
    simplifile.write(to: dir <> "/index.js", contents: entrypoint)

  let wrangler_out =
    "name = \""
    <> config.worker_name
    <> "\"\n"
    <> "main = \"./build/dist/bundle.js\"\n"
    <> "compatibility_date = \""
    <> config.compatibility_date
    <> "\"\n"
  let assert Ok(_) =
    simplifile.write(to: dir <> "/wrangler_out.toml", contents: wrangler_out)

  let assert Ok(entrypoint_content) = simplifile.read(dir <> "/index.js")
  entrypoint_content
  |> string.contains("import * as handler from \"./pipeline_test.mjs\"")
  |> should.be_true

  let assert Ok(wrangler_content) = simplifile.read(dir <> "/wrangler_out.toml")
  wrangler_content
  |> string.contains("name = \"pipeline-test\"")
  |> should.be_true

  let _ = simplifile.delete(dir)
}
