import { Ok, Error } from "./gleam.mjs";

export function d1_int(value) {
  return value;
}

export function d1_float(value) {
  return value;
}

export function d1_text(value) {
  return value;
}

export function d1_bool(value) {
  return value;
}

export function d1_blob(value) {
  return new Uint8Array(value);
}

export function d1_null() {
  return null;
}

export function d1_prepare(db, query) {
  return db.prepare(query);
}

export function d1_bind(statement, values) {
  return statement.bind(...values);
}

export async function d1_run(statement) {
  try {
    const result = await statement.run();
    return new Ok({
      results: result.results,
      success: result.success,
      meta: result.meta,
    });
  } catch (error) {
    return new Error(`${error}`);
  }
}

export async function d1_first(statement) {
  try {
    const result = await statement.first();
    return new Ok(result === null ? undefined : result);
  } catch (error) {
    return new Error(`${error}`);
  }
}

export async function d1_all(statement) {
  try {
    const result = await statement.all();
    return new Ok({
      results: result.results,
      success: result.success,
      meta: result.meta,
    });
  } catch (error) {
    return new Error(`${error}`);
  }
}

export async function d1_batch(db, statements) {
  try {
    const results = await db.batch(statements);
    return new Ok(results);
  } catch (error) {
    return new Error(`${error}`);
  }
}

export async function d1_exec(db, query) {
  try {
    const result = await db.exec(query);
    return new Ok({
      results: result.results,
      success: result.success,
      meta: result.meta,
    });
  } catch (error) {
    return new Error(`${error}`);
  }
}

export async function d1_dump(db) {
  try {
    const result = await db.dump();
    return new Ok(result);
  } catch (error) {
    return new Error(`${error}`);
  }
}

export async function d1_with_session(db, session) {
  try {
    const result = db.withSession(session);
    return new Ok(result);
  } catch (error) {
    return new Error(`${error}`);
  }
}
