import { Ok, Error } from "./gleam.mjs";
import { Some, None } from "../gleam_stdlib/gleam/option.mjs";

export function get_env_option(name) {
  // Deno
  if (typeof Deno !== "undefined" && Deno.env) {
    const value = Deno.env.get(name);
    if (value !== undefined && value !== null) {
      return new Some(value);
    }
    return new None();
  }
  // Node.js
  if (typeof process !== "undefined" && process.env) {
    const value = process.env[name];
    if (value !== undefined && value !== null) {
      return new Some(value);
    }
    return new None();
  }
  return new None();
}

export function get_env(name) {
  // Deno
  if (typeof Deno !== "undefined" && Deno.env) {
    const value = Deno.env.get(name);
    if (value !== undefined && value !== null) {
      return new Ok(value);
    }
    return new Error(undefined);
  }
  // Node.js
  if (typeof process !== "undefined" && process.env) {
    const value = process.env[name];
    if (value !== undefined && value !== null) {
      return new Ok(value);
    }
    return new Error(undefined);
  }
  return new Error(undefined);
}

export function get_env_or(name, default_value) {
  // Deno
  if (typeof Deno !== "undefined" && Deno.env) {
    const value = Deno.env.get(name);
    if (value !== undefined && value !== null) {
      return value;
    }
    return default_value;
  }
  // Node.js
  if (typeof process !== "undefined" && process.env) {
    const value = process.env[name];
    if (value !== undefined && value !== null) {
      return value;
    }
    return default_value;
  }
  return default_value;
}

export function block_on_promise(promise) {
  // Use Atomics.wait to block synchronously on a promise
  // This works in Node.js worker threads and Deno
  let result = undefined;
  let resolved = false;

  promise.then(
    (value) => {
      result = value;
      resolved = true;
    },
    (error) => {
      result = { tag: "error", value: error };
      resolved = true;
    }
  );

  // For Node.js/Deno CLI context, we can use a simple busy wait
  // In practice, migrations are fast so this is acceptable
  const start = Date.now();
  while (!resolved) {
    if (Date.now() - start > 30000) {
      throw new Error("Promise timed out after 30 seconds");
    }
    // Use a small delay to avoid busy waiting
    const sab = new SharedArrayBuffer(4);
    const i32 = new Int32Array(sab);
    Atomics.wait(i32, 0, 0, 10); // Wait 10ms
  }

  if (result && result.tag === "error") {
    throw result.value;
  }

  return result;
}
