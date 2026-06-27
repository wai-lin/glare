import gflare/cli/toml_utils.{type Config, type DoClass}
import gleam/dict
import gleam/list
import gleam/result
import gleam/string
import simplifile

pub fn entrypoint(
  output_path: String,
  package_name: String,
  handlers: List(String),
  do_classes: List(DoClass),
) -> Result(Nil, String) {
  let content = build_entrypoint_js(package_name, handlers, do_classes)
  simplifile.write(to: output_path, contents: content)
  |> result.map_error(fn(e) {
    "Failed to write entrypoint: " <> string.inspect(e)
  })
}

fn build_entrypoint_js(
  package_name: String,
  handlers: List(String),
  do_classes: List(DoClass),
) -> String {
  let imports = [
    "import * as handler from \"../dev/javascript/"
    <> package_name
    <> "/"
    <> package_name
    <> ".mjs\";",
    ..list.map(do_classes, fn(cls) {
      "import { "
      <> cls.name
      <> " } from \"../dev/javascript/"
      <> package_name
      <> "/"
      <> cls.module
      <> "_wrapped.mjs\";"
    })
  ]

  let handler_exports =
    list.filter_map(handlers, fn(h) {
      case h {
        "queue" ->
          Ok(
            "export async function queue(batch, env, ctx) {\n"
            <> "  const messages = batch.messages.map(msg => ({\n"
            <> "    id: msg.id,\n"
            <> "    timestamp: msg.timestamp,\n"
            <> "    body: msg.body,\n"
            <> "    attempts: msg.attempts,\n"
            <> "    ack: () => msg.ack(),\n"
            <> "    retry: () => msg.retry(),\n"
            <> "  }));\n"
            <> "  return handler.queue({ messages }, env, ctx);\n"
            <> "}",
          )
        "alarm" -> Error(Nil)
        _ -> Ok(
          "export async function " <> h <> "(...args) {\n"
          <> "  return handler." <> h <> "(...args);\n"
          <> "}",
        )
      }
    })

  let do_export_names = list.map(do_classes, fn(cls) { cls.name })

  let exports_block = case handler_exports {
    [] -> ""
    _ -> string.join(handler_exports, "\n\n")
  }

  let do_export_block = case do_export_names {
    [] -> ""
    names -> "\nexport { " <> string.join(names, ", ") <> " };"
  }

  string.join(imports, "\n")
  <> "\n\n"
  <> exports_block
  <> do_export_block
  <> "\n"
}

pub fn wrangler_config(
  output_path: String,
  worker_name: String,
  compat_date: String,
  config: Config,
) -> Result(Nil, String) {
  let content = build_wrangler_toml(worker_name, compat_date, config)
  simplifile.write(to: output_path, contents: content)
  |> result.map_error(fn(e) {
    "Failed to write wrangler.toml: " <> string.inspect(e)
  })
}

fn build_wrangler_toml(
  worker_name: String,
  compat_date: String,
  config: Config,
) -> String {
  let cf = config.cloudflare

  let header = [
    "name = \"" <> worker_name <> "\"",
    "main = \"./build/dist/index.js\"",
    "compatibility_date = \"" <> compat_date <> "\"",
    "",
  ]

  let kv_lines =
    list.flat_map(cf.bindings.kv, fn(name) {
      [
        "[[kv_namespaces]]",
        "binding = \"" <> name <> "\"",
        "id = \"YOUR_KV_NAMESPACE_ID\"",
        "",
      ]
    })

  let d1_lines =
    list.flat_map(cf.bindings.d1, fn(name) {
      [
        "[[d1_databases]]",
        "binding = \"" <> name <> "\"",
        "database_name = \""
          <> worker_name
          <> "-"
          <> string.lowercase(name)
          <> "\"",
        "database_id = \"YOUR_D1_DATABASE_ID\"",
        "",
      ]
    })

  let r2_lines =
    list.flat_map(cf.bindings.r2, fn(name) {
      [
        "[[r2_buckets]]",
        "binding = \"" <> name <> "\"",
        "bucket_name = \""
          <> worker_name
          <> "-"
          <> string.lowercase(name)
          <> "\"",
        "",
      ]
    })

  let queue_producer_lines =
    list.flat_map(cf.bindings.queues_producers, fn(name) {
      [
        "[[queues.producers]]",
        "binding = \"" <> name <> "\"",
        "queue_name = \"" <> string.lowercase(name) <> "\"",
        "",
      ]
    })

  let queue_consumer_lines =
    list.flat_map(cf.bindings.queues_consumers, fn(queue_name) {
      [
        "[[queues.consumers]]",
        "queue = \"" <> queue_name <> "\"",
        "",
      ]
    })

  let do_lines = case cf.durable_objects.classes {
    [] -> []
    classes -> {
      let bindings =
        list.map(classes, fn(cls) {
          "{ name = \""
          <> cls.name
          <> "\", class_name = \""
          <> cls.name
          <> "\" }"
        })
      [
        "[durable_objects]",
        "bindings = [" <> string.join(bindings, ", ") <> "]",
        "",
      ]
    }
  }

  let var_lines = case dict.is_empty(cf.vars) {
    True -> []
    False -> {
      let lines =
        dict.fold(cf.vars, [], fn(acc, key, value) {
          list.append(acc, [key <> " = \"" <> value <> "\""])
        })
      list.append(["[vars]"], lines)
    }
  }

  string.join(
    list.flatten([
      header,
      kv_lines,
      d1_lines,
      r2_lines,
      queue_producer_lines,
      queue_consumer_lines,
      do_lines,
      var_lines,
    ]),
    "\n",
  )
}

pub fn do_class(
  root_dir: String,
  package_name: String,
  class_config: DoClass,
) -> Result(Nil, String) {
  let module_path = class_config.module
  let gleam_mjs_path =
    root_dir
    <> "/build/dev/javascript/"
    <> package_name
    <> "/"
    <> module_path
    <> ".mjs"

  case simplifile.is_file(gleam_mjs_path) {
    Ok(True) -> {
      let content = build_do_class_js(module_path, class_config.name)
      let output_path =
        root_dir
        <> "/build/dev/javascript/"
        <> package_name
        <> "/"
        <> module_path
        <> "_wrapped.mjs"
      simplifile.write(to: output_path, contents: content)
      |> result.map_error(fn(e) {
        "Failed to write DO wrapper: " <> string.inspect(e)
      })
    }
    _ ->
      Error(
        "Durable Object module not found at "
        <> gleam_mjs_path
        <> ". Skipping "
        <> class_config.name
        <> " wrapper generation.",
      )
  }
}

fn build_do_class_js(module_path: String, class_name: String) -> String {
  "import { DurableObject } from \"cloudflare:workers\";
import * as gleamModule from \"./" <> module_path <> ".mjs\";

export class " <> class_name <> " extends DurableObject {
  constructor(state, env) {
    super(state, env);
    if (typeof gleamModule.create === \"function\") {
      gleamModule.create(state, env);
    }
  }

  async fetch(request) {
    if (typeof gleamModule.fetch === \"function\") {
      return gleamModule.fetch(this, request);
    }
    return new Response(\"Not implemented\", { status: 501 });
  }

  async alarm() {
    if (typeof gleamModule.alarm === \"function\") {
      return gleamModule.alarm(this);
    }
  }

  async webSocketMessage(ws, message) {
    if (typeof gleamModule.web_socket_message === \"function\") {
      return gleamModule.web_socket_message(this, ws, message);
    }
  }

  async webSocketClose(ws, code, reason, wasClean) {
    if (typeof gleamModule.web_socket_close === \"function\") {
      return gleamModule.web_socket_close(this, ws, code, reason, wasClean);
    }
  }

  async webSocketError(ws, error) {
    if (typeof gleamModule.web_socket_error === \"function\") {
      return gleamModule.web_socket_error(this, ws, error);
    }
  }
}
"
}
