import gflare/bindings.{type Env}
import gflare/request.{type HttpRequest}
import gflare/response.{type Response}
import gflare/worker.{type Context}
import gleam/dict.{type Dict}
import gleam/javascript/promise.{type Promise}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

pub type Router {
  Router(
    tree: TreeNode,
    global_middleware: List(Middleware),
    error_handler: fn(HttpRequest, String) -> Response,
    not_found_handler: Handler,
  )
}

pub type TreeNode {
  TreeNode(
    children: Dict(String, TreeNode),
    param_child: Option(ParamNode),
    wildcard_child: Option(WildcardNode),
    handlers: Dict(String, Handler),
    middleware: List(Middleware),
  )
}

pub type ParamNode {
  ParamNode(name: String, node: TreeNode)
}

pub type WildcardNode {
  WildcardNode(name: String, handler: Handler)
}

pub type Handler {
  Handler(fn(HttpRequest, Env, Context, RouteParams) -> Promise(Response))
}

pub type RouteParams {
  RouteParams(params: List(#(String, String)))
}

pub type Middleware {
  Middleware(fn(HttpRequest, Env, Context, Handler) -> Promise(Response))
}

// Constructor

/// Create a new empty router.
pub fn new() -> Router {
  Router(
    tree: new_node(),
    global_middleware: [],
    error_handler: default_error_handler,
    not_found_handler: Handler(fn(_req, _env, _ctx, _params) {
      use _ <- promise.await(promise.resolve(Nil))
      response.not_found()
      |> promise.resolve
    }),
  )
}

// Route builders

/// Add a GET route to the router.
pub fn get(router: Router, path: String, handler: Handler) -> Router {
  add_route(router, "GET", path, handler)
}

/// Add a POST route to the router.
pub fn post(router: Router, path: String, handler: Handler) -> Router {
  add_route(router, "POST", path, handler)
}

/// Add a PUT route to the router.
pub fn put(router: Router, path: String, handler: Handler) -> Router {
  add_route(router, "PUT", path, handler)
}

/// Add a DELETE route to the router.
pub fn delete(router: Router, path: String, handler: Handler) -> Router {
  add_route(router, "DELETE", path, handler)
}

/// Add a PATCH route to the router.
pub fn patch(router: Router, path: String, handler: Handler) -> Router {
  add_route(router, "PATCH", path, handler)
}

/// Add an OPTIONS route to the router.
pub fn options(router: Router, path: String, handler: Handler) -> Router {
  add_route(router, "OPTIONS", path, handler)
}

/// Add a route for all HTTP methods.
pub fn any(router: Router, path: String, handler: Handler) -> Router {
  router
  |> add_route("GET", path, handler)
  |> add_route("HEAD", path, handler)
  |> add_route("POST", path, handler)
  |> add_route("PUT", path, handler)
  |> add_route("DELETE", path, handler)
  |> add_route("PATCH", path, handler)
  |> add_route("OPTIONS", path, handler)
}

// Middleware

/// Add global middleware to the router.
pub fn with_middleware(router: Router, middleware: Middleware) -> Router {
  Router(
    ..router,
    global_middleware: list.append(router.global_middleware, [middleware]),
  )
}

// Groups

/// Create a route group with a shared prefix and middleware.
pub fn group(
  router: Router,
  prefix: String,
  middleware: List(Middleware),
  configure: fn(Router) -> Router,
) -> Router {
  // Create a temporary router to collect routes
  let temp_router = new()
  let configured = configure(temp_router)

  // Add all routes from configured router with prefix and middleware
  let tree_with_prefix =
    insert_tree_with_prefix(router.tree, prefix, configured.tree, middleware)

  Router(..router, tree: tree_with_prefix)
}

// Error handling

/// Set a custom 404 handler for the router.
pub fn not_found(router: Router, handler: Handler) -> Router {
  Router(..router, not_found_handler: handler)
}

/// Set a custom error handler for the router.
pub fn on_error(
  router: Router,
  handler: fn(HttpRequest, String) -> Response,
) -> Router {
  Router(..router, error_handler: handler)
}

// Serve

/// Serve a request using the router. Returns a Promise with the response.
pub fn serve(
  router: Router,
  request: HttpRequest,
  env: Env,
  ctx: Context,
) -> Promise(Response) {
  let method = request.method(request)
  let url = request.url(request)
  let path = get_path(url)
  let segments = parse_path_segments(path)

  // Try to match route
  case match_route(router.tree, segments, method, []) {
    Ok(#(handler, params, route_middleware)) -> {
      // Execute middleware chain: global first, then route-specific
      let all_middleware = list.append(router.global_middleware, route_middleware)
      execute_middleware_chain(
        all_middleware,
        request,
        env,
        ctx,
        handler,
        RouteParams(params),
        router.error_handler,
      )
    }
    Error(RouteNotFound) -> {
      // Try other methods to determine 405 vs 404
      let allowed = find_allowed_methods(router.tree, segments)
      case allowed {
        [] ->
          execute_handler(
            router.not_found_handler,
            request,
            env,
            ctx,
            RouteParams([]),
          )
        methods -> {
          use _ <- promise.await(promise.resolve(Nil))
          response.method_not_allowed(methods)
          |> promise.resolve
        }
      }
    }
    Error(MethodNotAllowed) -> {
      let allowed = find_allowed_methods(router.tree, segments)
      use _ <- promise.await(promise.resolve(Nil))
      response.method_not_allowed(allowed)
      |> promise.resolve
    }
  }
}

// Route params

/// Get a route parameter by name. Returns Some(value) if found, None otherwise.
pub fn get_param(params: RouteParams, name: String) -> Option(String) {
  find_param(params.params, name)
}

/// Get a route parameter by name with a default value if not found.
pub fn get_param_or(
  params: RouteParams,
  name: String,
  default: String,
) -> String {
  case get_param(params, name) {
    Some(value) -> value
    None -> default
  }
}

// Internal types

type MatchError {
  RouteNotFound
  MethodNotAllowed
}

// Internal functions

fn new_node() -> TreeNode {
  TreeNode(
    children: dict.new(),
    param_child: None,
    wildcard_child: None,
    handlers: dict.new(),
    middleware: [],
  )
}

fn add_route(
  router: Router,
  method: String,
  path: String,
  handler: Handler,
) -> Router {
  let segments = parse_path_segments(path)
  let tree = insert_route(router.tree, segments, method, handler)
  Router(..router, tree:)
}

fn insert_route(
  tree: TreeNode,
  segments: List(String),
  method: String,
  handler: Handler,
) -> TreeNode {
  insert_segments(tree, segments, method, handler)
}

fn insert_segments(
  node: TreeNode,
  segments: List(String),
  method: String,
  handler: Handler,
) -> TreeNode {
  case segments {
    [] -> {
      let handlers = dict.insert(node.handlers, method, handler)
      TreeNode(..node, handlers:)
    }
    [segment, ..rest] -> {
      case segment {
        "*" <> wildcard_name -> {
          // Wildcards must be the last segment
          case rest {
            [] -> {
              let wildcard = WildcardNode(wildcard_name, handler)
              TreeNode(..node, wildcard_child: Some(wildcard))
            }
            _ ->
              panic as "Wildcard segment must be the last segment in the path"
          }
        }
        ":" <> param_name -> {
          let child = case node.param_child {
            Some(existing) -> existing.node
            None -> new_node()
          }
          let updated_child = insert_segments(child, rest, method, handler)
          TreeNode(
            ..node,
            param_child: Some(ParamNode(param_name, updated_child)),
          )
        }
        _ -> {
          let child = case dict.get(node.children, segment) {
            Ok(existing) -> existing
            Error(_) -> new_node()
          }
          let updated_child = insert_segments(child, rest, method, handler)
          let children = dict.insert(node.children, segment, updated_child)
          TreeNode(..node, children:)
        }
      }
    }
  }
}

fn match_route(
  node: TreeNode,
  segments: List(String),
  method: String,
  accumulated_middleware: List(Middleware),
) -> Result(#(Handler, List(#(String, String)), List(Middleware)), MatchError) {
  let all_middleware = list.append(accumulated_middleware, node.middleware)
  case segments {
    [] -> {
      case dict.get(node.handlers, method) {
        Ok(handler) -> Ok(#(handler, [], all_middleware))
        Error(_) -> {
          // Path exists but method not allowed
          case dict.size(node.handlers) > 0 {
            True -> Error(MethodNotAllowed)
            False -> Error(RouteNotFound)
          }
        }
      }
    }
    [segment, ..rest] -> {
      // Try static match first (most specific)
      case dict.get(node.children, segment) {
        Ok(child) -> match_route(child, rest, method, all_middleware)
        Error(_) -> {
          // Try param match
          case node.param_child {
            Some(param) -> {
              case match_route(param.node, rest, method, all_middleware) {
                Ok(#(handler, params, mw)) ->
                  Ok(#(handler, [#(param.name, segment), ..params], mw))
                Error(RouteNotFound) -> {
                  // Try wildcard match
                  case node.wildcard_child {
                Some(wildcard) -> {
                      let remaining = join_segments(segments)
                      Ok(
                        #(wildcard.handler, [
                          #(wildcard.name, remaining),
                        ], all_middleware),
                      )
                    }
                    None -> Error(RouteNotFound)
                  }
                }
                Error(e) -> Error(e)
              }
            }
            None -> {
              // Try wildcard match
              case node.wildcard_child {
                Some(wildcard) -> {
                  let remaining = join_segments(segments)
                  Ok(
                    #(wildcard.handler, [
                      #(wildcard.name, remaining),
                    ], all_middleware),
                  )
                }
                None -> Error(RouteNotFound)
              }
            }
          }
        }
      }
    }
  }
}

fn find_allowed_methods(
  node: TreeNode,
  segments: List(String),
) -> List(String) {
  case segments {
    [] -> dict.keys(node.handlers)
    [segment, ..rest] -> {
      case dict.get(node.children, segment) {
        Ok(child) -> find_allowed_methods(child, rest)
        Error(_) ->
          case node.param_child {
            Some(param) -> find_allowed_methods(param.node, rest)
            None ->
              case node.wildcard_child {
                Some(_wildcard) -> {
                  // Wildcard handler exists, return its supported methods
                  ["GET", "POST", "PUT", "DELETE", "PATCH"]
                }
                None -> []
              }
          }
      }
    }
  }
}

fn execute_middleware_chain(
  middlewares: List(Middleware),
  request: HttpRequest,
  env: Env,
  ctx: Context,
  handler: Handler,
  params: RouteParams,
  error_handler: fn(HttpRequest, String) -> Response,
) -> Promise(Response) {
  case middlewares {
    [] ->
      safe_execute_handler(handler, request, env, ctx, params, error_handler)
    [middleware, ..rest] -> {
      let next =
        Handler(fn(req, env, ctx, _params) {
          execute_middleware_chain(
            rest,
            req,
            env,
            ctx,
            handler,
            params,
            error_handler,
          )
        })
      execute_middleware(middleware, request, env, ctx, next, error_handler)
    }
  }
}

fn execute_middleware(
  middleware: Middleware,
  request: HttpRequest,
  env: Env,
  ctx: Context,
  next: Handler,
  _error_handler: fn(HttpRequest, String) -> Response,
) -> Promise(Response) {
  let Middleware(handler_fn) = middleware
  handler_fn(request, env, ctx, next)
}

fn safe_execute_handler(
  handler: Handler,
  request: HttpRequest,
  env: Env,
  ctx: Context,
  params: RouteParams,
  _error_handler: fn(HttpRequest, String) -> Response,
) -> Promise(Response) {
  let Handler(handler_fn) = handler
  handler_fn(request, env, ctx, params)
}

fn execute_handler(
  handler: Handler,
  request: HttpRequest,
  env: Env,
  ctx: Context,
  params: RouteParams,
) -> Promise(Response) {
  let Handler(handler_fn) = handler
  handler_fn(request, env, ctx, params)
}

fn default_error_handler(request: HttpRequest, error: String) -> Response {
  let method = request.method(request)
  let url = request.url(request)
  let path = get_path(url)

  response.internal_error(error)
  |> response.set_header("x-request-method", method)
  |> response.set_header("x-request-path", path)
}

// Helpers

fn parse_path_segments(path: String) -> List(String) {
  // Remove query string
  let clean_path = case string.split(path, "?") {
    [p, _] -> p
    [p] -> p
    _ -> path
  }

  // Remove trailing slash
  let clean_path = case string.ends_with(clean_path, "/") {
    True -> string.drop_end(clean_path, 1)
    False -> clean_path
  }

  // Split and filter empty segments
  string.split(clean_path, "/")
  |> list.filter(fn(s) { s != "" })
}

fn join_segments(segments: List(String)) -> String {
  string.join(segments, "/")
}

fn get_path(url: String) -> String {
  case string.split(url, "?") {
    [path, _] -> path
    [path] -> path
    _ -> url
  }
}

fn find_param(params: List(#(String, String)), name: String) -> Option(String) {
  case params {
    [] -> None
    [#(k, v), ..rest] -> {
      case k == name {
        True -> Some(v)
        False -> find_param(rest, name)
      }
    }
  }
}

fn insert_tree_with_prefix(
  existing: TreeNode,
  prefix: String,
  new_tree: TreeNode,
  middleware: List(Middleware),
) -> TreeNode {
  let prefix_segments = parse_path_segments(prefix)
  insert_tree_at_prefix(existing, prefix_segments, new_tree, middleware)
}

fn insert_tree_at_prefix(
  node: TreeNode,
  segments: List(String),
  new_tree: TreeNode,
  middleware: List(Middleware),
) -> TreeNode {
  case segments {
    [] -> {
      // Merge handlers
      let handlers = dict.merge(node.handlers, new_tree.handlers)
      let children = dict.merge(node.children, new_tree.children)
      let all_middleware = list.append(middleware, node.middleware)
      TreeNode(..node, handlers:, children:, middleware: all_middleware)
    }
    [segment, ..rest] -> {
      let child = case dict.get(node.children, segment) {
        Ok(existing) -> existing
        Error(_) -> new_node()
      }
      let updated_child = insert_tree_at_prefix(child, rest, new_tree, middleware)
      let children = dict.insert(node.children, segment, updated_child)
      TreeNode(..node, children:)
    }
  }
}
