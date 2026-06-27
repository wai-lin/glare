import gleeunit
import gleeunit/should

import gflare/cli/db/generate
import gflare/cli/db/types.{
  Both, D1, GBitArray, GBool, GFloat, GInt, GOption, GString, ParsedQuery,
  QueryParam, ResultSet, Turso,
}
import gleam/io
import gleam/string
import simplifile

pub fn main() {
  gleeunit.main()
}

fn generate_and_read(queries, backend, path) -> String {
  case generate.generate_sql_module(queries, backend, path) {
    Ok(Nil) ->
      case simplifile.read(path) {
        Ok(content) -> {
          let _ = simplifile.delete(path)
          content
        }
        Error(_) -> {
          should.fail()
          ""
        }
      }
    Error(e) -> {
      io.println(e)
      should.fail()
      ""
    }
  }
}

fn should_contain(haystack: String, needle: String) {
  case string.contains(haystack, needle) {
    True -> Nil
    False -> {
      io.println("Expected content to contain: " <> needle)
      should.fail()
    }
  }
}

fn should_not_contain(haystack: String, needle: String) {
  case string.contains(haystack, needle) {
    False -> Nil
    True -> {
      io.println("Expected content NOT to contain: " <> needle)
      should.fail()
    }
  }
}

// D1 module generation tests

pub fn generate_d1_select_with_returns_test() {
  let queries = [
    ParsedQuery(
      name: "find_user",
      params: [QueryParam(name: "user_id", gleam_type: GInt)],
      returns: [
        ResultSet(name: "id", gleam_type: GInt),
        ResultSet(name: "name", gleam_type: GString),
      ],
      sql: "SELECT id, name FROM users WHERE id = ?1",
      backends: [D1],
      returns_many: False,
    ),
  ]
  let content = generate_and_read(queries, D1, "/tmp/test_d1_select.gleam")
  should_contain(content, "pub type FindUserRow")
  should_contain(content, "FindUserRow(")
  should_contain(content, "id: Int")
  should_contain(content, "name: String")
  should_contain(content, "pub fn find_user(")
  should_contain(content, "db: d1.Database")
  should_contain(content, "decode.int")
  should_contain(content, "decode.string")
}

pub fn generate_d1_insert_no_returns_test() {
  let queries = [
    ParsedQuery(
      name: "create_user",
      params: [
        QueryParam(name: "name", gleam_type: GString),
        QueryParam(name: "email", gleam_type: GString),
      ],
      returns: [],
      sql: "INSERT INTO users (name, email) VALUES (?1, ?2)",
      backends: [D1],
      returns_many: False,
    ),
  ]
  let content = generate_and_read(queries, D1, "/tmp/test_d1_insert.gleam")
  should_contain(content, "pub fn create_user(")
  should_not_contain(content, "pub type CreateUserRow")
  should_contain(content, "d1.D1Result")
  should_contain(content, "d1.text(name)")
  should_contain(content, "d1.text(email)")
}

pub fn generate_d1_with_option_return_test() {
  let queries = [
    ParsedQuery(
      name: "find_optional",
      params: [QueryParam(name: "id", gleam_type: GInt)],
      returns: [
        ResultSet(name: "id", gleam_type: GInt),
        ResultSet(name: "email", gleam_type: GOption(GString)),
      ],
      sql: "SELECT id, email FROM users WHERE id = ?1",
      backends: [D1],
      returns_many: False,
    ),
  ]
  let content = generate_and_read(queries, D1, "/tmp/test_d1_option.gleam")
  should_contain(content, "email: Option(String)")
  should_contain(content, "decode.optional(decode.string)")
}

// Turso module generation tests

pub fn generate_turso_select_with_returns_test() {
  let queries = [
    ParsedQuery(
      name: "find_item",
      params: [QueryParam(name: "item_id", gleam_type: GInt)],
      returns: [
        ResultSet(name: "id", gleam_type: GInt),
        ResultSet(name: "name", gleam_type: GString),
        ResultSet(name: "price", gleam_type: GFloat),
      ],
      sql: "SELECT id, name, price FROM items WHERE id = ?1",
      backends: [Turso],
      returns_many: False,
    ),
  ]
  let content =
    generate_and_read(queries, Turso, "/tmp/test_turso_select.gleam")
  should_contain(content, "pub type FindItemRow")
  should_contain(content, "id: Int")
  should_contain(content, "name: String")
  should_contain(content, "price: Float")
  should_contain(content, "pub fn find_item(")
  should_contain(content, "config: turso.Config")
  should_contain(content, "turso.int(item_id)")
  should_contain(content, "extract_turso_value")
}

pub fn generate_turso_insert_no_returns_test() {
  let queries = [
    ParsedQuery(
      name: "insert_item",
      params: [
        QueryParam(name: "name", gleam_type: GString),
        QueryParam(name: "price", gleam_type: GFloat),
      ],
      returns: [],
      sql: "INSERT INTO items (name, price) VALUES (?1, ?2)",
      backends: [Turso],
      returns_many: False,
    ),
  ]
  let content =
    generate_and_read(queries, Turso, "/tmp/test_turso_insert.gleam")
  should_contain(content, "pub fn insert_item(")
  should_not_contain(content, "pub type InsertItemRow")
  should_contain(content, "turso.ExecuteResult")
  should_contain(content, "turso.text(name)")
  should_contain(content, "turso.float(price)")
}

// Multiple queries test

pub fn generate_multiple_queries_test() {
  let queries = [
    ParsedQuery(
      name: "find_user",
      params: [QueryParam(name: "id", gleam_type: GInt)],
      returns: [
        ResultSet(name: "id", gleam_type: GInt),
        ResultSet(name: "name", gleam_type: GString),
      ],
      sql: "SELECT id, name FROM users WHERE id = ?1",
      backends: [D1],
      returns_many: False,
    ),
    ParsedQuery(
      name: "list_users",
      params: [],
      returns: [
        ResultSet(name: "id", gleam_type: GInt),
        ResultSet(name: "name", gleam_type: GString),
      ],
      sql: "SELECT id, name FROM users",
      backends: [D1],
      returns_many: False,
    ),
  ]
  let content = generate_and_read(queries, D1, "/tmp/test_multi.gleam")
  should_contain(content, "pub type FindUserRow")
  should_contain(content, "pub type ListUsersRow")
  should_contain(content, "pub fn find_user(")
  should_contain(content, "pub fn list_users(")
}

// SQL escaping tests

pub fn generate_sql_with_quotes_test() {
  let queries = [
    ParsedQuery(
      name: "search",
      params: [QueryParam(name: "term", gleam_type: GString)],
      returns: [],
      sql: "SELECT * FROM users WHERE name LIKE '%test%'",
      backends: [D1],
      returns_many: False,
    ),
  ]
  let content = generate_and_read(queries, D1, "/tmp/test_quotes.gleam")
  should_contain(content, "pub fn search(")
  should_contain(content, "d1.text(term)")
}

pub fn generate_sql_with_newlines_test() {
  let queries = [
    ParsedQuery(
      name: "multi_line",
      params: [],
      returns: [],
      sql: "SELECT\n  id,\n  name\nFROM users",
      backends: [D1],
      returns_many: False,
    ),
  ]
  let content = generate_and_read(queries, D1, "/tmp/test_newlines.gleam")
  should_contain(content, "pub fn multi_line(")
}

// Type mapping tests

pub fn generate_d1_bool_param_test() {
  let queries = [
    ParsedQuery(
      name: "toggle",
      params: [QueryParam(name: "active", gleam_type: GBool)],
      returns: [],
      sql: "UPDATE users SET active = ?1",
      backends: [D1],
      returns_many: False,
    ),
  ]
  let content = generate_and_read(queries, D1, "/tmp/test_bool.gleam")
  should_contain(content, "d1.int(active)")
}

pub fn generate_d1_blob_param_test() {
  let queries = [
    ParsedQuery(
      name: "upload",
      params: [QueryParam(name: "data", gleam_type: GBitArray)],
      returns: [],
      sql: "INSERT INTO files (data) VALUES (?1)",
      backends: [D1],
      returns_many: False,
    ),
  ]
  let content = generate_and_read(queries, D1, "/tmp/test_blob.gleam")
  should_contain(content, "d1.blob(data)")
}

pub fn generate_turso_date_param_test() {
  let queries = [
    ParsedQuery(
      name: "by_date",
      params: [QueryParam(name: "created", gleam_type: GString)],
      returns: [],
      sql: "SELECT * FROM events WHERE date = ?1",
      backends: [Turso],
      returns_many: False,
    ),
  ]
  let content = generate_and_read(queries, Turso, "/tmp/test_date.gleam")
  should_contain(content, "turso.text(created)")
}

// Empty params test

pub fn generate_no_params_test() {
  let queries = [
    ParsedQuery(
      name: "count_all",
      params: [],
      returns: [ResultSet(name: "count", gleam_type: GInt)],
      sql: "SELECT COUNT(*) as count FROM users",
      backends: [D1],
      returns_many: False,
    ),
  ]
  let content = generate_and_read(queries, D1, "/tmp/test_no_params.gleam")
  should_contain(content, "pub fn count_all(")
  should_contain(content, "d1.Database")
  // The generated code includes d1.bind even with no params
  should_contain(content, "d1.prepare(db,")
  should_contain(content, "d1.first()")
}

// Import verification tests

pub fn generate_d1_imports_test() {
  let queries = [
    ParsedQuery(
      name: "test",
      params: [],
      returns: [],
      sql: "SELECT 1",
      backends: [D1],
      returns_many: False,
    ),
  ]
  let content = generate_and_read(queries, D1, "/tmp/test_imports.gleam")
  should_contain(content, "import gleam/dynamic/decode")
  should_contain(content, "import gleam/javascript/promise")
  should_contain(content, "import gleam/option.{type Option, None, Some}")
  should_contain(content, "import gflare/d1")
  should_contain(content, "import gflare/error.{type Error}")
}

pub fn generate_turso_imports_test() {
  let queries = [
    ParsedQuery(
      name: "test",
      params: [],
      returns: [],
      sql: "SELECT 1",
      backends: [Turso],
      returns_many: False,
    ),
  ]
  let content =
    generate_and_read(queries, Turso, "/tmp/test_turso_imports.gleam")
  should_contain(content, "import gleam/javascript/promise")
  should_contain(content, "import gleam/list")
  should_contain(content, "import gleam/option.{type Option, None, Some}")
  should_contain(content, "import gleam/result")
  should_contain(content, "import gflare/turso")
  should_contain(content, "import gflare/turso/error.{type TursoError}")
  should_contain(content, "import gflare/turso/types.{type Value}")
}

// Decoder generation tests

pub fn generate_decoder_with_multiple_fields_test() {
  let queries = [
    ParsedQuery(
      name: "complex",
      params: [],
      returns: [
        ResultSet(name: "id", gleam_type: GInt),
        ResultSet(name: "name", gleam_type: GString),
        ResultSet(name: "score", gleam_type: GFloat),
        ResultSet(name: "active", gleam_type: GBool),
      ],
      sql: "SELECT * FROM complex_table",
      backends: [D1],
      returns_many: False,
    ),
  ]
  let content = generate_and_read(queries, D1, "/tmp/test_decoder.gleam")
  should_contain(content, "use id <- decode.field(0, decode.int)")
  should_contain(content, "use name <- decode.field(1, decode.string)")
  should_contain(content, "use score <- decode.field(2, decode.float)")
  should_contain(content, "use active <- decode.field(3, decode.bool)")
}

// Error handling tests

pub fn generate_invalid_path_test() {
  let queries = [
    ParsedQuery(
      name: "test",
      params: [],
      returns: [],
      sql: "SELECT 1",
      backends: [D1],
      returns_many: False,
    ),
  ]
  let result =
    generate.generate_sql_module(queries, D1, "/nonexistent/dir/file.gleam")
  result |> should.be_error
}

// Dual backend tests

pub fn generate_both_backends_test() {
  let queries = [
    ParsedQuery(
      name: "find_user",
      params: [QueryParam(name: "user_id", gleam_type: GInt)],
      returns: [
        ResultSet(name: "id", gleam_type: GInt),
        ResultSet(name: "name", gleam_type: GString),
      ],
      sql: "SELECT id, name FROM users WHERE id = ?1",
      backends: [D1, Turso],
      returns_many: False,
    ),
  ]
  // Use the multi-file generation for dual backend
  let output_dir = "/tmp/test_both_gen"
  let _ = simplifile.create_directory(output_dir)
  let result =
    generate.generate_sql_modules(queries, Both, output_dir, "test_app")
  // Verify the result
  case result {
    Ok(Nil) -> Nil
    Error(e) -> {
      io.println(e)
      should.fail()
    }
  }
  // Verify the generated files
  verify_dual_backend_output(output_dir)
}

fn verify_dual_backend_output(output_dir: String) {
  let d1_path = output_dir <> "/d1_sql.gleam"
  let turso_path = output_dir <> "/turso_sql.gleam"
  let shared_path = output_dir <> "/sql_shared.gleam"

  case simplifile.read(d1_path) {
    Ok(content) -> {
      should_contain(content, "pub fn find_user(")
      should_contain(content, "db: d1.Database")
      should_contain(content, "decode.int")
    }
    Error(_) -> should.fail()
  }

  case simplifile.read(turso_path) {
    Ok(content) -> {
      should_contain(content, "pub fn find_user(")
      should_contain(content, "turso.Config")
      should_contain(content, "turso.int(user_id)")
    }
    Error(_) -> should.fail()
  }

  case simplifile.read(shared_path) {
    Ok(content) -> {
      should_contain(content, "pub type FindUserRow")
      should_contain(content, "id: Int")
      should_contain(content, "name: String")
    }
    Error(_) -> should.fail()
  }

  // Clean up
  let _ = simplifile.delete(d1_path)
  let _ = simplifile.delete(turso_path)
  let _ = simplifile.delete(shared_path)
  let _ = simplifile.delete(output_dir)
}

// returns_many tests

pub fn generate_d1_returns_many_test() {
  let queries = [
    ParsedQuery(
      name: "list_users",
      params: [],
      returns: [
        ResultSet(name: "id", gleam_type: GInt),
        ResultSet(name: "name", gleam_type: GString),
      ],
      sql: "SELECT id, name FROM users ORDER BY name",
      backends: [D1],
      returns_many: True,
    ),
  ]
  let content = generate_and_read(queries, D1, "/tmp/test_returns_many.gleam")
  should_contain(content, "d1.all()")
  should_not_contain(content, "d1.first()")
  should_contain(content, "List(ListUsersRow)")
  should_contain(content, "list.filter_map(d1_result.results")
}

pub fn generate_d1_returns_many_with_params_test() {
  let queries = [
    ParsedQuery(
      name: "list_user_posts",
      params: [QueryParam(name: "user_id", gleam_type: GInt)],
      returns: [
        ResultSet(name: "id", gleam_type: GInt),
        ResultSet(name: "title", gleam_type: GString),
      ],
      sql: "SELECT id, title FROM posts WHERE user_id = ?1",
      backends: [D1],
      returns_many: True,
    ),
  ]
  let content =
    generate_and_read(queries, D1, "/tmp/test_returns_many_params.gleam")
  should_contain(content, "d1.all()")
  should_contain(content, "List(ListUserPostsRow)")
  should_contain(content, "d1.int(user_id)")
}

pub fn generate_d1_returns_single_test() {
  let queries = [
    ParsedQuery(
      name: "find_user",
      params: [QueryParam(name: "id", gleam_type: GInt)],
      returns: [
        ResultSet(name: "id", gleam_type: GInt),
        ResultSet(name: "name", gleam_type: GString),
      ],
      sql: "SELECT id, name FROM users WHERE id = ?1",
      backends: [D1],
      returns_many: False,
    ),
  ]
  let content = generate_and_read(queries, D1, "/tmp/test_returns_single.gleam")
  should_contain(content, "d1.first()")
  should_not_contain(content, "d1.all()")
  should_contain(content, "FindUserRow")
  should_not_contain(content, "List(")
}

pub fn generate_turso_returns_many_test() {
  let queries = [
    ParsedQuery(
      name: "list_items",
      params: [],
      returns: [
        ResultSet(name: "id", gleam_type: GInt),
        ResultSet(name: "name", gleam_type: GString),
      ],
      sql: "SELECT id, name FROM items",
      backends: [Turso],
      returns_many: True,
    ),
  ]
  let content =
    generate_and_read(queries, Turso, "/tmp/test_turso_returns_many.gleam")
  should_contain(content, "List(ListItemsRow)")
  should_contain(content, "list.filter_map(execute_result.rows")
}

pub fn generate_no_returns_many_without_annotation_test() {
  let queries = [
    ParsedQuery(
      name: "count_users",
      params: [],
      returns: [ResultSet(name: "count", gleam_type: GInt)],
      sql: "SELECT COUNT(*) as count FROM users",
      backends: [D1],
      returns_many: False,
    ),
  ]
  let content =
    generate_and_read(queries, D1, "/tmp/test_no_returns_many.gleam")
  should_contain(content, "d1.first()")
  should_not_contain(content, "List(CountUsersRow)")
}

// Syntax correctness tests

pub fn d1_decoder_block_uses_colon_shorthand_test() {
  let queries = [
    ParsedQuery(
      name: "find_user",
      params: [QueryParam(name: "user_id", gleam_type: GInt)],
      returns: [
        ResultSet(name: "id", gleam_type: GInt),
        ResultSet(name: "name", gleam_type: GString),
        ResultSet(name: "email", gleam_type: GString),
      ],
      sql: "SELECT id, name, email FROM users WHERE id = ?1",
      backends: [D1],
      returns_many: False,
    ),
  ]
  let content = generate_and_read(queries, D1, "/tmp/test_syntax.gleam")
  should_contain(content, "decode.success(FindUserRow(id:, name:, email:))")
  should_not_contain(content, "FindUserRow(    id")
}

pub fn d1_decoder_no_stray_colon_before_close_test() {
  let queries = [
    ParsedQuery(
      name: "get_count",
      params: [],
      returns: [ResultSet(name: "count", gleam_type: GInt)],
      sql: "SELECT COUNT(*) as count FROM users",
      backends: [D1],
      returns_many: False,
    ),
  ]
  let content = generate_and_read(queries, D1, "/tmp/test_single_field.gleam")
  should_contain(content, "decode.success(GetCountRow(count:))")
  should_not_contain(content, "count: )")
}

pub fn turso_single_row_uses_colon_shorthand_test() {
  let queries = [
    ParsedQuery(
      name: "find_item",
      params: [QueryParam(name: "item_id", gleam_type: GInt)],
      returns: [
        ResultSet(name: "id", gleam_type: GInt),
        ResultSet(name: "name", gleam_type: GString),
      ],
      sql: "SELECT id, name FROM items WHERE id = ?1",
      backends: [Turso],
      returns_many: False,
    ),
  ]
  let content =
    generate_and_read(queries, Turso, "/tmp/test_turso_syntax.gleam")
  should_contain(content, "Ok(FindItemRow(id:, name:))")
  should_not_contain(content, "FindItemRow(id, name)")
  should_not_contain(content, "FindItemRow(id, name:)")
}

pub fn turso_returns_many_uses_colon_shorthand_test() {
  let queries = [
    ParsedQuery(
      name: "list_items",
      params: [],
      returns: [
        ResultSet(name: "id", gleam_type: GInt),
        ResultSet(name: "name", gleam_type: GString),
      ],
      sql: "SELECT id, name FROM items",
      backends: [Turso],
      returns_many: True,
    ),
  ]
  let content =
    generate_and_read(queries, Turso, "/tmp/test_turso_many_syntax.gleam")
  should_contain(content, "Ok(ListItemsRow(id:, name:))")
  should_not_contain(content, "ListItemsRow(id, name)")
  should_not_contain(content, "list.first")
}

pub fn d1_returns_many_decoder_block_test() {
  let queries = [
    ParsedQuery(
      name: "list_users",
      params: [],
      returns: [
        ResultSet(name: "id", gleam_type: GInt),
        ResultSet(name: "name", gleam_type: GString),
      ],
      sql: "SELECT id, name FROM users",
      backends: [D1],
      returns_many: True,
    ),
  ]
  let content = generate_and_read(queries, D1, "/tmp/test_d1_many_syntax.gleam")
  should_contain(content, "decode.success(ListUsersRow(id:, name:))")
  should_contain(content, "d1.all()")
  should_contain(content, "list.filter_map(d1_result.results")
}

// No-params query tests (stray comma bug)

pub fn d1_no_params_select_test() {
  let queries = [
    ParsedQuery(
      name: "count_users",
      params: [],
      returns: [ResultSet(name: "count", gleam_type: GInt)],
      sql: "SELECT COUNT(*) as count FROM users",
      backends: [D1],
      returns_many: False,
    ),
  ]
  let content = generate_and_read(queries, D1, "/tmp/test_no_params.gleam")
  should_contain(content, "d1.first()")
  should_not_contain(content, "d1.bind([")
  should_not_contain(content, ",)")
}

pub fn d1_no_params_returns_many_test() {
  let queries = [
    ParsedQuery(
      name: "list_all",
      params: [],
      returns: [
        ResultSet(name: "id", gleam_type: GInt),
        ResultSet(name: "name", gleam_type: GString),
      ],
      sql: "SELECT id, name FROM users",
      backends: [D1],
      returns_many: True,
    ),
  ]
  let content = generate_and_read(queries, D1, "/tmp/test_no_params_many.gleam")
  should_contain(content, "d1.all()")
  should_not_contain(content, "d1.bind([")
}

pub fn d1_no_params_insert_test() {
  let queries = [
    ParsedQuery(
      name: "reset_counter",
      params: [],
      returns: [],
      sql: "UPDATE counters SET value = 0",
      backends: [D1],
      returns_many: False,
    ),
  ]
  let content =
    generate_and_read(queries, D1, "/tmp/test_no_params_insert.gleam")
  should_contain(content, "d1.run()")
  should_not_contain(content, "d1.bind([")
}

pub fn turso_no_params_select_test() {
  let queries = [
    ParsedQuery(
      name: "count_items",
      params: [],
      returns: [ResultSet(name: "count", gleam_type: GInt)],
      sql: "SELECT COUNT(*) as count FROM items",
      backends: [Turso],
      returns_many: False,
    ),
  ]
  let content =
    generate_and_read(queries, Turso, "/tmp/test_turso_no_params.gleam")
  should_contain(content, "turso.execute(config,")
  should_not_contain(content, ", [")
}

pub fn turso_no_params_returns_many_test() {
  let queries = [
    ParsedQuery(
      name: "list_all_items",
      params: [],
      returns: [
        ResultSet(name: "id", gleam_type: GInt),
        ResultSet(name: "name", gleam_type: GString),
      ],
      sql: "SELECT id, name FROM items",
      backends: [Turso],
      returns_many: True,
    ),
  ]
  let content =
    generate_and_read(queries, Turso, "/tmp/test_turso_no_params_many.gleam")
  should_contain(content, "turso.execute(config,")
  should_not_contain(content, ", [")
}
