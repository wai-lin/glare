import glare/error.{type Error}
import glare/kv.{type Kv}
import glare/d1.{type Database}
import glare/r2.{type Bucket}
import glare/durable_object.{type Namespace}
import glare/queue.{type Queue}

pub type Env

@external(javascript, "glare_ffi_bindings.mjs", "get_kv")
pub fn kv(env: Env, name: String) -> Result(Kv, Error)

@external(javascript, "glare_ffi_bindings.mjs", "get_d1")
pub fn d1(env: Env, name: String) -> Result(Database, Error)

@external(javascript, "glare_ffi_bindings.mjs", "get_r2")
pub fn r2(env: Env, name: String) -> Result(Bucket, Error)

@external(javascript, "glare_ffi_bindings.mjs", "get_do_namespace")
pub fn durable_object(env: Env, name: String) -> Result(Namespace, Error)

@external(javascript, "glare_ffi_bindings.mjs", "get_queue_producer")
pub fn queue_producer(env: Env, name: String) -> Result(Queue, Error)

@external(javascript, "glare_ffi_bindings.mjs", "get_var")
pub fn var(env: Env, name: String) -> Result(String, Error)

@external(javascript, "glare_ffi_bindings.mjs", "get_secret")
pub fn secret(env: Env, name: String) -> Result(String, Error)
