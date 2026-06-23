import gleeunit
import gleeunit/should

import gflare/migrate/parse
import gleam/int
import gleam/io
import gleam/list
import gleam/order
import gleam/string
import simplifile

pub fn main() {
  gleeunit.main()
}

// Migration type tests

pub fn migration_construction_test() {
  let migration =
    parse.Migration(
      version: 1,
      name: "0001_create_users",
      path: "db/migrations/0001_create_users.sql",
      sql: "CREATE TABLE users (id INTEGER PRIMARY KEY)",
    )
  migration.version |> should.equal(1)
  migration.name |> should.equal("0001_create_users")
  migration.path |> should.equal("db/migrations/0001_create_users.sql")
  migration.sql |> should.equal("CREATE TABLE users (id INTEGER PRIMARY KEY)")
}

// parse_version tests (now using int.parse)

pub fn parse_version_single_digit_test() {
  int.parse("1") |> should.equal(Ok(1))
}

pub fn parse_version_multi_digit_test() {
  int.parse("0001") |> should.equal(Ok(1))
}

pub fn parse_version_large_number_test() {
  int.parse("12345") |> should.equal(Ok(12_345))
}

pub fn parse_version_zero_test() {
  int.parse("0") |> should.equal(Ok(0))
}

pub fn parse_version_invalid_test() {
  int.parse("abc") |> should.equal(Error(Nil))
}

pub fn parse_version_mixed_test() {
  int.parse("12abc") |> should.equal(Error(Nil))
}

pub fn parse_version_empty_test() {
  // Empty string returns Error(Nil) since int.parse can't parse empty string
  int.parse("") |> should.equal(Error(Nil))
}

// parse_version_from_name tests

pub fn parse_version_from_name_standard_test() {
  parse.parse_version_from_name("0001_create_users") |> should.equal(Ok(1))
}

pub fn parse_version_from_name_multi_digit_test() {
  parse.parse_version_from_name("0042_add_email_index") |> should.equal(Ok(42))
}

pub fn parse_version_from_name_no_underscore_test() {
  parse.parse_version_from_name("create_users") |> should.equal(Error(Nil))
}

pub fn parse_version_from_name_invalid_version_test() {
  parse.parse_version_from_name("abc_create_users") |> should.equal(Error(Nil))
}

pub fn parse_version_from_name_empty_test() {
  // Empty string split returns [""] which tries to parse "" as version
  // int.parse("") returns Error(Nil) since empty string is not a valid integer
  parse.parse_version_from_name("") |> should.equal(Error(Nil))
}

// int_compare tests

pub fn int_compare_less_test() {
  int.compare(1, 2) |> should.equal(order.Lt)
}

pub fn int_compare_greater_test() {
  int.compare(2, 1) |> should.equal(order.Gt)
}

pub fn int_compare_equal_test() {
  int.compare(1, 1) |> should.equal(order.Eq)
}

pub fn int_compare_zero_test() {
  int.compare(0, 0) |> should.equal(order.Eq)
}

// int_to_string tests

pub fn int_to_string_zero_test() {
  int.to_string(0) |> should.equal("0")
}

pub fn int_to_string_one_test() {
  int.to_string(1) |> should.equal("1")
}

pub fn int_to_string_multi_digit_test() {
  int.to_string(123) |> should.equal("123")
}

pub fn int_to_string_large_test() {
  int.to_string(9999) |> should.equal("9999")
}

// parse_migration_file tests (filesystem-based)

fn test_dir_name(n: Int) -> String {
  "./test_tmp_migrate_" <> int.to_string(n)
}

pub fn parse_migration_file_test() {
  let dir = test_dir_name(1)
  let _ = simplifile.create_directory_all(dir)
  let filepath = dir <> "/0001_create_users.sql"
  let content =
    "-- Create users table\nCREATE TABLE users (id INTEGER PRIMARY KEY);"
  let _ = simplifile.write(to: filepath, contents: content)

  case parse.parse_migration_file(filepath) {
    Ok(migration) -> {
      migration.version |> should.equal(1)
      migration.name |> should.equal("0001_create_users")
      migration.path |> should.equal(filepath)
      string.contains(migration.sql, "CREATE TABLE users") |> should.be_true()
    }
    Error(e) -> {
      io.println(e)
      should.fail()
    }
  }

  let _ = simplifile.delete(dir)
}

pub fn parse_migration_file_with_comments_test() {
  let dir = test_dir_name(2)
  let _ = simplifile.create_directory_all(dir)
  let filepath = dir <> "/0002_add_email.sql"
  let content =
    "-- Migration: add email\n-- Created at: 2026-01-01\n\nALTER TABLE users ADD COLUMN email TEXT;"
  let _ = simplifile.write(to: filepath, contents: content)

  case parse.parse_migration_file(filepath) {
    Ok(migration) -> {
      migration.version |> should.equal(2)
      migration.name |> should.equal("0002_add_email")
      string.contains(migration.sql, "ALTER TABLE users") |> should.be_true()
      string.contains(migration.sql, "Migration:") |> should.be_false()
    }
    Error(e) -> {
      io.println(e)
      should.fail()
    }
  }

  let _ = simplifile.delete(dir)
}

pub fn parse_migration_file_empty_sql_test() {
  let dir = test_dir_name(3)
  let _ = simplifile.create_directory_all(dir)
  let filepath = dir <> "/0003_empty.sql"
  let content = "-- Just a comment\n"
  let _ = simplifile.write(to: filepath, contents: content)

  case parse.parse_migration_file(filepath) {
    Ok(_) -> should.fail()
    Error(_) -> Nil
  }

  let _ = simplifile.delete(dir)
}

pub fn parse_migration_file_invalid_name_test() {
  let dir = test_dir_name(4)
  let _ = simplifile.create_directory_all(dir)
  let filepath = dir <> "/invalid_name.sql"
  let content = "CREATE TABLE test (id INTEGER);"
  let _ = simplifile.write(to: filepath, contents: content)

  case parse.parse_migration_file(filepath) {
    Ok(_) -> should.fail()
    Error(_) -> Nil
  }

  let _ = simplifile.delete(dir)
}

// list_pending tests

pub fn list_pending_empty_dir_test() {
  let dir = test_dir_name(5)
  let _ = simplifile.create_directory_all(dir)

  case parse.list_pending(dir, []) {
    Ok(migrations) -> list.length(migrations) |> should.equal(0)
    Error(e) -> {
      io.println(e)
      should.fail()
    }
  }

  let _ = simplifile.delete(dir)
}

pub fn list_pending_with_migrations_test() {
  let dir = test_dir_name(6)
  let _ = simplifile.create_directory_all(dir)

  let _ =
    simplifile.write(
      to: dir <> "/0001_create_users.sql",
      contents: "CREATE TABLE users (id INTEGER);",
    )
  let _ =
    simplifile.write(
      to: dir <> "/0002_add_email.sql",
      contents: "ALTER TABLE users ADD COLUMN email TEXT;",
    )

  case parse.list_pending(dir, []) {
    Ok(migrations) -> {
      list.length(migrations) |> should.equal(2)
      case migrations {
        [first, second] -> {
          first.version |> should.equal(1)
          second.version |> should.equal(2)
        }
        _ -> should.fail()
      }
    }
    Error(e) -> {
      io.println(e)
      should.fail()
    }
  }

  let _ = simplifile.delete(dir)
}

pub fn list_pending_skips_applied_test() {
  let dir = test_dir_name(7)
  let _ = simplifile.create_directory_all(dir)

  let _ =
    simplifile.write(
      to: dir <> "/0001_create_users.sql",
      contents: "CREATE TABLE users (id INTEGER);",
    )
  let _ =
    simplifile.write(
      to: dir <> "/0002_add_email.sql",
      contents: "ALTER TABLE users ADD COLUMN email TEXT;",
    )

  case parse.list_pending(dir, ["0001_create_users"]) {
    Ok(migrations) -> {
      list.length(migrations) |> should.equal(1)
      case migrations {
        [migration] -> migration.version |> should.equal(2)
        _ -> should.fail()
      }
    }
    Error(e) -> {
      io.println(e)
      should.fail()
    }
  }

  let _ = simplifile.delete(dir)
}

pub fn list_pending_sorts_by_version_test() {
  let dir = test_dir_name(8)
  let _ = simplifile.create_directory_all(dir)

  let _ = simplifile.write(to: dir <> "/0003_third.sql", contents: "SELECT 3;")
  let _ = simplifile.write(to: dir <> "/0001_first.sql", contents: "SELECT 1;")
  let _ = simplifile.write(to: dir <> "/0002_second.sql", contents: "SELECT 2;")

  case parse.list_pending(dir, []) {
    Ok(migrations) -> {
      list.length(migrations) |> should.equal(3)
      case migrations {
        [first, second, third] -> {
          first.version |> should.equal(1)
          second.version |> should.equal(2)
          third.version |> should.equal(3)
        }
        _ -> should.fail()
      }
    }
    Error(e) -> {
      io.println(e)
      should.fail()
    }
  }

  let _ = simplifile.delete(dir)
}

pub fn list_pending_nonexistent_dir_test() {
  case parse.list_pending("./nonexistent_dir_xyz", []) {
    Ok(_) -> should.fail()
    Error(_) -> Nil
  }
}
