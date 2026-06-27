import gflare/cli/toml_utils.{type DoClass}
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
      <> cls.class_name
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
        _ ->
          Ok(
            "export async function "
            <> h
            <> "(...args) {\n"
            <> "  return handler."
            <> h
            <> "(...args);\n"
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

pub fn do_class(
  root_dir: String,
  package_name: String,
  class_config: DoClass,
) -> Result(Nil, String) {
  let module_path = class_config.class_name
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
