import argv
import glint
import gflare/cli/build
import gflare/cli/db
import gflare/cli/init

pub fn main() {
  let app =
    glint.new()
    |> glint.with_name("gflare")
    |> glint.as_module
    |> glint.global_help("Zero-glue Gleam framework for Cloudflare Workers")
    |> glint.add(at: [], do: build_command())
    |> glint.add(at: ["init"], do: init_command())
    |> glint.add(at: ["build"], do: build_command())
    |> glint.add(at: ["dev"], do: dev_command())
    |> glint.add(at: ["deploy"], do: deploy_command())
    |> glint.add(at: ["db"], do: db_command())

  let args = argv.load().arguments
  glint.run(app, args)
}

fn init_command() {
  use <- glint.command_help("Initialize Cloudflare Workers in the current project")
  use _, _, _ <- glint.command()
  init.run()
}

fn build_command() {
  use <- glint.command_help("Build for Cloudflare Workers")
  use _, _, _ <- glint.command()
  build.run(deploy: False, dev: False)
}

fn dev_command() {
  use <- glint.command_help("Build and start local dev server")
  use _, _, _ <- glint.command()
  build.run(deploy: False, dev: True)
}

fn deploy_command() {
  use <- glint.command_help("Build and deploy to Cloudflare")
  use _, _, _ <- glint.command()
  build.run(deploy: True, dev: False)
}

fn db_command() {
  use <- glint.command_help("Database tools (generate, migrate)")
  use _, _, _ <- glint.command()
  db.run()
}
