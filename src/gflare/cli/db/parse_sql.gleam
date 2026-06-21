import gflare/cli/db/types.{
  type ParsedQuery, type QueryParam, type ResultSet, ParsedQuery, QueryParam, ResultSet,
  parse_gleam_type,
}
import gleam/list
import gleam/result
import gleam/string
import simplifile

pub type SqlParseError {
  FileError(path: String, message: String)
  ParseError(path: String, message: String)
}

fn parse_param_line(line: String) -> List(QueryParam) {
  line
  |> string.trim
  |> string.split(",")
  |> list.filter_map(fn(part) {
    case string.split(string.trim(part), ":") {
      [name, type_str] ->
        Ok(QueryParam(name: string.trim(name), gleam_type: parse_gleam_type(string.trim(type_str))))
      _ -> Error(Nil)
    }
  })
}

fn parse_return_line(line: String) -> List(ResultSet) {
  line
  |> string.trim
  |> string.split(",")
  |> list.filter_map(fn(part) {
    case string.split(string.trim(part), ":") {
      [name, type_str] ->
        Ok(ResultSet(name: string.trim(name), gleam_type: parse_gleam_type(string.trim(type_str))))
      _ -> Error(Nil)
    }
  })
}

fn parse_sql_content(content: String) -> Result(ParsedQuery, SqlParseError) {
  let lines = string.split(content, "\n")

  let params = list.filter_map(lines, fn(line) {
    let trimmed = string.trim(line)
    case string.starts_with(trimmed, "-- params:") {
      True -> {
        let param_str = string.drop_start(trimmed, 10) |> string.trim
        Ok(parse_param_line(param_str))
      }
      False -> Error(Nil)
    }
  })
  |> list.flatten

  let returns = list.filter_map(lines, fn(line) {
    let trimmed = string.trim(line)
    case string.starts_with(trimmed, "-- returns:") {
      True -> {
        let return_str = string.drop_start(trimmed, 11) |> string.trim
        Ok(parse_return_line(return_str))
      }
      False -> Error(Nil)
    }
  })
  |> list.flatten

  let sql_lines = list.filter_map(lines, fn(line) {
    let trimmed = string.trim(line)
    case string.starts_with(trimmed, "--") {
      True -> Error(Nil)
      False ->
        case trimmed {
          "" -> Error(Nil)
          _ -> Ok(trimmed)
        }
    }
  })

  let sql = string.join(sql_lines, "\n")

  case sql {
    "" -> Error(ParseError(path: "", message: "No SQL query found"))
    _ ->
      Ok(ParsedQuery(
        name: "",
        params:,
        returns:,
        sql:,
      ))
  }
}

pub fn parse_file(path: String) -> Result(ParsedQuery, SqlParseError) {
  case simplifile.read(path) {
    Ok(content) -> {
      case parse_sql_content(content) {
        Ok(query) -> {
          let name = extract_name_from_path(path)
          Ok(ParsedQuery(..query, name:))
        }
        Error(e) -> Error(ParseError(path:, message: "Failed to parse SQL: " <> e.message))
      }
    }
    Error(e) ->
      Error(FileError(path:, message: "Failed to read file: " <> simplifile.describe_error(e)))
  }
}

fn extract_name_from_path(path: String) -> String {
  path
  |> string.split("/")
  |> list.last
  |> result.unwrap("")
  |> string.replace(".sql", "")
}

pub fn find_sql_files(dir: String) -> Result(List(String), SqlParseError) {
  case simplifile.get_files(dir) {
    Ok(files) -> {
      let sql_files =
        files
        |> list.filter(fn(f) { string.ends_with(f, ".sql") })
        |> list.sort(string.compare)
      Ok(sql_files)
    }
    Error(e) ->
      Error(FileError(
        path: dir,
        message: "Failed to read directory: " <> simplifile.describe_error(e),
      ))
  }
}

pub fn parse_file_content(content: String) -> Result(ParsedQuery, SqlParseError) {
  parse_sql_content(content)
}
