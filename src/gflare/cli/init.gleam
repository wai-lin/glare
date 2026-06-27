import gleam/io
import gleam/list
import gleam/result
import gleam/string
import simplifile

pub fn run() -> Nil {
  io.println("\nInitializing Cloudflare Workers in current project...")

  let outcome =
    simplifile.read("gleam.toml")
    |> result.map_error(fn(_) {
      "Could not read gleam.toml. Are you in a Gleam project?"
    })
    |> result.try(fn(content) { extract_package_name(content) })
    |> result.try(fn(package_name) {
      setup_wrangler_toml(package_name)
      |> result.map(fn(_) { package_name })
    })
    |> result.try(fn(package_name) { write_handler(package_name) })

  case outcome {
    Ok(_) -> {
      io.println("\nDone! Your project is ready for Cloudflare Workers.")
      io.println(
        "\n  1. Edit your handler file to add Cloudflare Workers handlers",
      )
      io.println("  2. Run: gleam run -m gflare -- build")
      io.println("  3. Run: gleam run -m gflare -- dev")
    }
    Error(msg) -> {
      io.println_error("Error: " <> msg)
    }
  }
}

fn extract_package_name(content: String) -> Result(String, String) {
  let lines = string.split(content, "\n")
  case list.find(lines, fn(line) { string.starts_with(line, "name = ") }) {
    Ok(line) -> {
      let name =
        line
        |> string.drop_start(7)
        |> string.trim
        |> string.replace("\"", with: "")
      case string.is_empty(name) {
        True -> Error("Could not parse package name from gleam.toml")
        False -> Ok(name)
      }
    }
    Error(_) -> Error("Could not find 'name' in gleam.toml")
  }
}

fn setup_wrangler_toml(package_name: String) -> Result(Nil, String) {
  let worker_name =
    package_name |> string.replace("_", with: "-") |> string.lowercase
  let today = do_get_iso_date()

  case simplifile.is_file("wrangler.toml") {
    Ok(True) -> {
      io.println("  wrangler.toml already exists")
      use content <- result.try(
        simplifile.read("wrangler.toml")
        |> result.map_error(fn(_) { "Failed to read wrangler.toml" }),
      )
      update_wrangler_toml(content, worker_name, today)
    }
    _ -> create_wrangler_toml(worker_name, today)
  }
}

fn create_wrangler_toml(
  worker_name: String,
  today: String,
) -> Result(Nil, String) {
  let content =
    "name = \""
    <> worker_name
    <> "\"\n"
    <> "main = \"./build/dist/bundle.js\"\n"
    <> "compatibility_date = \""
    <> today
    <> "\"\n"
  simplifile.write(to: "wrangler.toml", contents: content)
  |> result.map_error(fn(_) { "Failed to create wrangler.toml" })
}

fn update_wrangler_toml(
  content: String,
  worker_name: String,
  today: String,
) -> Result(Nil, String) {
  let lines = string.split(content, "\n")
  let has_name =
    list.any(lines, fn(line) { string.starts_with(line, "name = ") })
  let has_main =
    list.any(lines, fn(line) { string.starts_with(line, "main = ") })
  let has_compat =
    list.any(lines, fn(line) {
      string.starts_with(line, "compatibility_date = ")
    })

  case has_name && has_main && has_compat {
    True -> {
      io.println("  wrangler.toml already configured")
      Ok(Nil)
    }
    False -> {
      io.println("  Updating wrangler.toml with missing fields...")
      let updated = content
      let updated = case has_name {
        True -> updated
        False -> updated <> "\nname = \"" <> worker_name <> "\"\n"
      }
      let updated = case has_main {
        True -> updated
        False -> updated <> "main = \"./build/dist/bundle.js\"\n"
      }
      let updated = case has_compat {
        True -> updated
        False -> updated <> "compatibility_date = \"" <> today <> "\"\n"
      }
      simplifile.write(to: "wrangler.toml", contents: updated)
      |> result.map_error(fn(_) { "Failed to update wrangler.toml" })
    }
  }
}

fn write_handler(package_name: String) -> Result(Nil, String) {
  let handler_path = "src/" <> package_name <> ".gleam"

  case simplifile.is_file(handler_path) {
    Ok(True) -> {
      io.println("  Handler file already exists: " <> handler_path)
      io.println("  Edit it to add your Cloudflare Workers handlers.")
      Ok(Nil)
    }
    _ -> {
      let content =
        "import gflare/bindings.{type Env}\n"
        <> "import gflare/request.{type HttpRequest}\n"
        <> "import gflare/response\n"
        <> "import gflare/worker.{type Context}\n"
        <> "import gleam/javascript/promise\n"
        <> "\n"
        <> "pub fn fetch(request: HttpRequest, env: Env, ctx: Context) {\n"
        <> "  response.new(200)\n"
        <> "  |> response.set_body(\"Hello from "
        <> package_name
        <> "!\")\n"
        <> "  |> promise.resolve\n"
        <> "}\n"
      simplifile.write(to: handler_path, contents: content)
      |> result.map_error(fn(_) { "Failed to write handler file" })
    }
  }
}

@external(javascript, "../ffi.mjs", "get_iso_date")
fn do_get_iso_date() -> String
