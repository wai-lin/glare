import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/fetch
import gleam/http/request
import gleam/javascript/promise.{type Promise}
import gleam/json
import gleam/list
import gleam/result
import gflare/turso/error.{type TursoError, ApiError, DecodeError, NetworkError}

pub type CloudConfig {
  CloudConfig(org: String, token: String)
}

pub type Database {
  Database(
    name: String,
    db_id: String,
    hostname: String,
    group: String,
    primary_region: String,
  )
}

pub type TokenResult {
  TokenResult(jwt: String)
}

pub type Group {
  Group(name: String, location: String)
}

pub fn connect(org: String, token: String) -> CloudConfig {
  CloudConfig(org:, token:)
}

const base_url = "https://api.turso.tech/v1"

pub fn create_database(
  config: CloudConfig,
  name: String,
  group: String,
) -> Promise(Result(Database, TursoError)) {
  let url = base_url <> "/organizations/" <> config.org <> "/databases"
  let body = json.object([#("name", json.string(name)), #("group", json.string(group))])
  post_request(config, url, body, parse_database)
}

pub fn delete_database(
  config: CloudConfig,
  name: String,
) -> Promise(Result(Nil, TursoError)) {
  let url = base_url <> "/organizations/" <> config.org <> "/databases/" <> name
  delete_request(config, url)
}

pub fn retrieve_database(
  config: CloudConfig,
  name: String,
) -> Promise(Result(Database, TursoError)) {
  let url = base_url <> "/organizations/" <> config.org <> "/databases/" <> name
  get_request(config, url, parse_database)
}

pub fn list_databases(
  config: CloudConfig,
) -> Promise(Result(List(Database), TursoError)) {
  let url = base_url <> "/organizations/" <> config.org <> "/databases"
  get_request(config, url, parse_database_list)
}

pub fn create_token(
  config: CloudConfig,
  db_name: String,
  expiration: String,
  authorization: String,
) -> Promise(Result(TokenResult, TursoError)) {
  let url = base_url <> "/organizations/" <> config.org <> "/databases/" <> db_name <> "/auth/tokens?expiration=" <> expiration <> "&authorization=" <> authorization
  post_request(config, url, json.object([]), parse_token)
}

pub fn create_group(
  config: CloudConfig,
  name: String,
) -> Promise(Result(Group, TursoError)) {
  let url = base_url <> "/organizations/" <> config.org <> "/groups"
  let body = json.object([#("name", json.string(name))])
  post_request(config, url, body, parse_group)
}

pub fn delete_group(
  config: CloudConfig,
  name: String,
) -> Promise(Result(Nil, TursoError)) {
  let url = base_url <> "/organizations/" <> config.org <> "/groups/" <> name
  delete_request(config, url)
}

pub fn list_groups(
  config: CloudConfig,
) -> Promise(Result(List(Group), TursoError)) {
  let url = base_url <> "/organizations/" <> config.org <> "/groups"
  get_request(config, url, parse_group_list)
}

fn post_request(
  config: CloudConfig,
  url: String,
  body: json.Json,
  parser: fn(String) -> Result(a, String),
) -> Promise(Result(a, TursoError)) {
  let assert Ok(req) = request.to(url)
  let req =
    req
    |> request.set_header("Authorization", "Bearer " <> config.token)
    |> request.set_header("Content-Type", "application/json")
  let req = request.set_body(req, json.to_string(body))
  use fetch_result <- promise.await(fetch.send(req))
  case fetch_result {
    Ok(resp) -> {
      use text_result <- promise.await(fetch.read_text_body(resp))
      case text_result {
        Ok(text_resp) -> handle_response(resp.status, text_resp.body, parser)
        Error(_) -> promise.resolve(Error(NetworkError("Failed to read response")))
      }
    }
    Error(_) -> promise.resolve(Error(NetworkError("Failed to send request")))
  }
}

fn get_request(
  config: CloudConfig,
  url: String,
  parser: fn(String) -> Result(a, String),
) -> Promise(Result(a, TursoError)) {
  let assert Ok(req) = request.to(url)
  let req = req |> request.set_header("Authorization", "Bearer " <> config.token)
  use fetch_result <- promise.await(fetch.send(req))
  case fetch_result {
    Ok(resp) -> {
      use text_result <- promise.await(fetch.read_text_body(resp))
      case text_result {
        Ok(text_resp) -> handle_response(resp.status, text_resp.body, parser)
        Error(_) -> promise.resolve(Error(NetworkError("Failed to read response")))
      }
    }
    Error(_) -> promise.resolve(Error(NetworkError("Failed to send request")))
  }
}

fn delete_request(
  config: CloudConfig,
  url: String,
) -> Promise(Result(Nil, TursoError)) {
  let assert Ok(req) = request.to(url)
  let req = req |> request.set_header("Authorization", "Bearer " <> config.token)
  use fetch_result <- promise.await(fetch.send(req))
  case fetch_result {
    Ok(resp) -> {
      use text_result <- promise.await(fetch.read_text_body(resp))
      case text_result {
        Ok(text_resp) -> {
          case resp.status {
            200 -> promise.resolve(Ok(Nil))
            404 -> promise.resolve(Error(ApiError("Not found")))
            _ -> promise.resolve(Error(ApiError("Request failed: " <> text_resp.body)))
          }
        }
        Error(_) -> promise.resolve(Error(NetworkError("Failed to read response")))
      }
    }
    Error(_) -> promise.resolve(Error(NetworkError("Failed to send request")))
  }
}

fn handle_response(
  status: Int,
  body: String,
  parser: fn(String) -> Result(a, String),
) -> Promise(Result(a, TursoError)) {
  case status {
    200 -> {
      case parser(body) {
        Ok(value) -> promise.resolve(Ok(value))
        Error(msg) -> promise.resolve(Error(DecodeError(msg)))
      }
    }
    409 -> promise.resolve(Error(ApiError("Conflict")))
    404 -> promise.resolve(Error(ApiError("Not found")))
    _ -> promise.resolve(Error(ApiError("Request failed: " <> body)))
  }
}

fn parse_database(body: String) -> Result(Database, String) {
  use data <- result.try(parse_json(body))
  use database <- result.try(get_field(data, "database"))
  use name <- result.try(get_string(database, "Name"))
  use db_id <- result.try(get_string(database, "DbId"))
  use hostname <- result.try(get_string(database, "Hostname"))
  use group <- result.try(get_string(database, "group"))
  use primary_region <- result.try(get_string(database, "primaryRegion"))
  Ok(Database(name:, db_id:, hostname:, group:, primary_region:))
}

fn parse_database_list(body: String) -> Result(List(Database), String) {
  use data <- result.try(parse_json(body))
  use databases <- result.try(get_field(data, "databases"))
  use items <- result.try(get_list(databases))
  let decoded = list.filter_map(items, fn(item) {
    decode.run(item, decode_database_decoder())
  })
  Ok(decoded)
}

fn decode_database_decoder() {
  use name <- decode.field("Name", decode.string)
  use db_id <- decode.field("DbId", decode.string)
  use hostname <- decode.field("Hostname", decode.string)
  use group <- decode.field("group", decode.string)
  use primary_region <- decode.field("primaryRegion", decode.string)
  decode.success(Database(name:, db_id:, hostname:, group:, primary_region:))
}

fn parse_token(body: String) -> Result(TokenResult, String) {
  use data <- result.try(parse_json(body))
  use jwt <- result.try(get_string(data, "jwt"))
  Ok(TokenResult(jwt:))
}

fn parse_group(body: String) -> Result(Group, String) {
  use data <- result.try(parse_json(body))
  use group <- result.try(get_field(data, "group"))
  use name <- result.try(get_string(group, "Name"))
  use location <- result.try(get_string(group, "location"))
  Ok(Group(name:, location:))
}

fn parse_group_list(body: String) -> Result(List(Group), String) {
  use data <- result.try(parse_json(body))
  use groups <- result.try(get_field(data, "groups"))
  use items <- result.try(get_list(groups))
  let decoded = list.filter_map(items, fn(item) {
    decode.run(item, decode_group_decoder())
  })
  Ok(decoded)
}

fn decode_group_decoder() {
  use name <- decode.field("Name", decode.string)
  use location <- decode.field("location", decode.string)
  decode.success(Group(name:, location:))
}

fn parse_json(body: String) -> Result(Dynamic, String) {
  json.parse(body, decode.dynamic)
  |> result.map_error(fn(_) { "Failed to parse JSON" })
}

fn get_field(data: Dynamic, field_name: String) -> Result(Dynamic, String) {
  decode.run(data, decode.field(field_name, decode.dynamic, fn(v) { decode.success(v) }))
  |> result.map_error(fn(_) { "Field '" <> field_name <> "' not found" })
}

fn get_string(data: Dynamic, field_name: String) -> Result(String, String) {
  decode.run(data, decode.field(field_name, decode.string, decode.success))
  |> result.map_error(fn(_) { "String field '" <> field_name <> "' not found" })
}

fn get_list(data: Dynamic) -> Result(List(Dynamic), String) {
  decode.run(data, decode.list(decode.dynamic))
  |> result.map_error(fn(_) { "Not a list" })
}
