import { Ok, Error, List, NonEmpty, Empty } from "./gleam.mjs";

export function wait_until(ctx, promise) {
  ctx.waitUntil(promise);
}

export function pass_through_on_exception(ctx) {
  ctx.passThroughOnException();
}

export function new_response(status) {
  return new Response(null, { status });
}

export function set_body(response, body) {
  return new Response(body, {
    status: response.status,
    headers: response.headers,
  });
}

export function set_header(response, name, value) {
  const headers = new Headers(response.headers);
  headers.set(name, value);
  return new Response(response.body, {
    status: response.status,
    headers,
  });
}

export function response_json(response, data) {
  const headers = new Headers(response.headers);
  headers.set("content-type", "application/json");
  return new Response(JSON.stringify(data), {
    status: response.status,
    headers,
  });
}

export function append_header(response, name, value) {
  const headers = new Headers(response.headers);
  headers.append(name, value);
  return new Response(response.body, {
    status: response.status,
    headers,
  });
}

export function get_response_header(response, name) {
  const value = response.headers.get(name);
  if (value === null || value === undefined) {
    return new Error("Header not found: " + name);
  }
  return new Ok(value);
}

export function remove_response_header(response, name) {
  const headers = new Headers(response.headers);
  headers.delete(name);
  return new Response(response.body, {
    status: response.status,
    headers,
  });
}

export function response_bytes(response, data) {
  return new Response(data, {
    status: response.status,
    headers: response.headers,
  });
}

export function response_empty(status) {
  return new Response(null, { status });
}

export function redirect(url, status) {
  return Response.redirect(url, status);
}

export function request_url(request) {
  return request.url;
}

export function request_method(request) {
  return request.method;
}

export function request_headers(request) {
  const headers = [];
  request.headers.forEach((value, key) => {
    headers.push([key, value]);
  });
  return List.fromArray(headers);
}

export function request_body(request) {
  return request.body;
}

export async function request_text(request) {
  try {
    const text = await request.text();
    return new Ok(text);
  } catch (error) {
    return new Error(`${error}`);
  }
}

export async function request_json(request) {
  try {
    const json = await request.json();
    return new Ok(json);
  } catch (error) {
    return new Error(`${error}`);
  }
}

export async function request_array_buffer(request) {
  try {
    const buffer = await request.arrayBuffer();
    return new Ok(new Uint8Array(buffer));
  } catch (error) {
    return new Error(`${error}`);
  }
}
