import gleeunit
import gleeunit/should

import glare/cli/handlers

pub fn main() {
  gleeunit.main()
}

pub fn detect_fetch_handler_test() {
  let mjs = "export function fetch(request, env, ctx) {\n  return new Response('ok');\n}"
  handlers.detect_handlers(mjs)
  |> should.equal(["fetch"])
}

pub fn detect_scheduled_handler_test() {
  let mjs = "export async function scheduled(event) {\n  console.log('tick');\n}"
  handlers.detect_handlers(mjs)
  |> should.equal(["scheduled"])
}

pub fn detect_queue_handler_test() {
  let mjs = "export function queue(batch) {\n  batch.messages.forEach(m => m.ack());\n}"
  handlers.detect_handlers(mjs)
  |> should.equal(["queue"])
}

pub fn detect_multiple_handlers_test() {
  let mjs =
    "export function fetch(request) { return new Response('ok'); }\n"
    <> "export function queue(batch) { batch.messages.forEach(m => m.ack()); }\n"
    <> "export async function scheduled(event) { console.log('tick'); }\n"
  handlers.detect_handlers(mjs)
  |> should.equal(["fetch", "scheduled", "queue"])
}

pub fn detect_no_handlers_test() {
  let mjs = "const x = 42;\nexport default { x };\n"
  handlers.detect_handlers(mjs)
  |> should.equal([])
}

pub fn detect_no_false_positives_test() {
  let mjs = "export function fetcher(req) { return new Response('ok'); }\n"
  handlers.detect_handlers(mjs)
  |> should.equal([])
}

pub fn detect_async_fetch_test() {
  let mjs = "export async function fetch(request) { return new Response('ok'); }"
  handlers.detect_handlers(mjs)
  |> should.equal(["fetch"])
}

pub fn detect_all_six_handlers_test() {
  let mjs =
    "export function fetch(r) {}\n"
    <> "export function scheduled(e) {}\n"
    <> "export function queue(b) {}\n"
    <> "export function email(m) {}\n"
    <> "export function tail(e) {}\n"
    <> "export function alarm(a) {}\n"
  handlers.detect_handlers(mjs)
  |> should.equal(["fetch", "scheduled", "queue", "email", "tail", "alarm"])
}

pub fn detect_handlers_preserves_order_test() {
  let mjs =
    "export function scheduled(e) {}\n"
    <> "export function fetch(r) {}\n"
    <> "export function queue(b) {}\n"
  handlers.detect_handlers(mjs)
  |> should.equal(["fetch", "scheduled", "queue"])
}

pub fn detect_empty_content_test() {
  handlers.detect_handlers("")
  |> should.equal([])
}
