import gflare/cli/generate
import gflare/cli/handlers
import gflare/cli/toml_utils
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import shellout
import simplifile

pub fn run(deploy deployment: Bool, dev development: Bool) -> Nil {
  let result = do_build(deployment, development)
  case result {
    Ok(_) -> Nil
    Error(msg) -> {
      io.println_error("Error: " <> msg)
      shellout.exit(1)
    }
  }
}

fn do_build(deploy: Bool, dev: Bool) -> Result(Nil, String) {
  use config <- result.try(
    toml_utils.load_config()
    |> result.map_error(fn(e) { "Failed to load config: " <> e }),
  )

  let package_name = config.package_name
  let cf_config = config.cloudflare
  let cf_name = cf_config.name
  let compat_date = case cf_config.compatibility_date {
    "" -> do_get_iso_date()
    d -> d
  }

  io.println("Building Gleam project...")
  use _ <- result.try(run_gleam_build())

  let build_dir = "build/dev/javascript/" <> package_name
  let main_mjs = build_dir <> "/" <> package_name <> ".mjs"

  use main_content <- result.try(
    simplifile.read(main_mjs)
    |> result.map_error(fn(_) { "Compiled output not found at " <> main_mjs }),
  )

  let detected_handlers = handlers.detect_handlers(main_content)
  io.println(
    "Detected handlers: "
    <> case detected_handlers {
      [] -> "none"
      h -> string.join(h, ", ")
    },
  )

  let do_classes = cf_config.durable_objects.classes
  list.each(do_classes, fn(cls) {
    case generate.do_class(".", package_name, cls) {
      Ok(_) -> io.println("Generated DO wrapper: " <> cls.name)
      Error(msg) -> io.println("Warning: " <> msg)
    }
  })

  let dist_dir = "build/dist"
  use _ <- result.try(
    simplifile.create_directory_all(dist_dir)
    |> result.map_error(fn(_) { "Failed to create dist directory" }),
  )

  let entrypoint_path = dist_dir <> "/index.js"
  use _ <- result.try(generate.entrypoint(
    entrypoint_path,
    package_name,
    detected_handlers,
    do_classes,
  ))

  let wrangler_path = "wrangler.toml"
  use _ <- result.try(generate.wrangler_config(
    wrangler_path,
    cf_name,
    compat_date,
    config,
  ))

  io.println("Bundling with esbuild...")
  let output_path = dist_dir <> "/bundle.js"
  use _ <- result.try(run_esbuild(entrypoint_path, output_path))

  use _ <- result.try(update_wrangler_main(wrangler_path, output_path))

  io.println("\nBuild complete!\n")

  case deploy {
    True -> {
      io.println("Deploying to Cloudflare...")
      run_wrangler_deploy()
    }
    False ->
      case dev {
        True -> {
          io.println("Starting local dev server...")
          run_wrangler_dev()
        }
        False -> Ok(Nil)
      }
  }
}

fn run_gleam_build() -> Result(Nil, String) {
  case
    shellout.command("gleam", ["build", "--target", "javascript"], ".", [
      shellout.LetBeStdout,
    ])
  {
    Ok(_) -> Ok(Nil)
    Error(#(code, msg)) ->
      Error("gleam build failed (exit " <> string.inspect(code) <> "): " <> msg)
  }
}

fn run_esbuild(input: String, output: String) -> Result(Nil, String) {
  case
    shellout.command(
      "npx",
      [
        "esbuild",
        input,
        "--bundle",
        "--format=esm",
        "--platform=neutral",
        "--outfile=" <> output,
        "--conditions=import",
      ],
      ".",
      [shellout.LetBeStdout],
    )
  {
    Ok(_) -> Ok(Nil)
    Error(#(code, msg)) ->
      Error(
        "esbuild bundling failed (exit " <> string.inspect(code) <> "): " <> msg,
      )
  }
}

fn run_wrangler_dev() -> Result(Nil, String) {
  case
    shellout.command("npx", ["wrangler", "dev"], ".", [shellout.LetBeStdout])
  {
    Ok(_) -> Ok(Nil)
    Error(#(code, msg)) ->
      Error(
        "wrangler dev failed (exit " <> string.inspect(code) <> "): " <> msg,
      )
  }
}

fn run_wrangler_deploy() -> Result(Nil, String) {
  case
    shellout.command("npx", ["wrangler", "deploy"], ".", [shellout.LetBeStdout])
  {
    Ok(_) -> Ok(Nil)
    Error(#(code, msg)) ->
      Error(
        "wrangler deploy failed (exit " <> string.inspect(code) <> "): " <> msg,
      )
  }
}

fn update_wrangler_main(
  wrangler_path: String,
  output_path: String,
) -> Result(Nil, String) {
  use content <- result.try(
    simplifile.read(wrangler_path)
    |> result.map_error(fn(_) { "Failed to read wrangler.toml" }),
  )
  let relative_path = output_path
  let updated =
    content
    |> string.replace("./build/dist/index.js", with: "./" <> relative_path)
  simplifile.write(to: wrangler_path, contents: updated)
  |> result.map_error(fn(_) { "Failed to update wrangler.toml" })
}

@external(javascript, "../ffi.mjs", "get_iso_date")
fn do_get_iso_date() -> String
