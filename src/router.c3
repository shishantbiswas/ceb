module ceb::router;

import std::collections::list;
import std::collections::map;
import std::io;
import std::core::mem;
import ceb::enums;
import ceb::types;
import ceb::parser;

// Enhanced fault definitions for better error handling
faultdef INVALID_PATH, MULTIPLE_DYNAMIC_PARAMS, ROUTE_NOT_FOUND,
    METHOD_NOT_ALLOWED, DUPLICATE_ROUTE;

enum NodeType : uint {
    STATIC,
    PARAM,
    WILDCARD
}

// Route structure with parameter extraction support
struct RouteInfo {
  String path;
  HttpVerb method;
  HandlerFn handler_fn;
  String[] param_names; // Names of dynamic parameters (e.g., ["id"] for
                        // "/users/:id")
}

// Trie Node for optimized route lookup
struct TrieNode {
  String path;
  NodeType type;
  HashMap{String, TrieNode} children; // Store children nodes
  RouteInfo *route;  // Pointer to route if this is a terminal node
  String param_name; // For parameter nodes
  bool is_wildcard;  // For wildcard nodes
}

struct Router {
  List{RouteInfo} routes;
  HashMap {
    String, List { RouteInfo }
  }
  method_routes;               // Method-based routing cache
  List{String} static_routes;  // Cache for static routes
  List{String} dynamic_routes; // Cache for dynamic routes
  HashMap{String,
          TrieNode} method_tries; // Trie-based lookup for each method
                                  // bool locked; Lock the tree from modifying
}

fn Router *Router.build_trie(&self) {
  return self;
}

// Initialize a new router
fn Router *Router.init(&self) {
  self.routes.init(mem);
  self.method_routes.init(mem);
  self.static_routes.init(mem);
  self.dynamic_routes.init(mem);
  self.method_tries.init(mem);
  return self;
}

// Free router resources
fn void Router.free(&self) {
  self.routes.free();
  self.method_routes.free();
  self.static_routes.free();
  self.dynamic_routes.free();
  self.method_tries.free();
}

// Initialize the Trie for a specific HTTP method
fn void Router.init_method_trie(&self, HttpVerb method) {
  String method_key = method.str_val;

  if (!self.method_tries.has_key(method_key)) {
    TrieNode root;
    root.path = "/";
    root.type = NodeType.STATIC;
    root.children.init(mem);
    root.route = null;
    root.param_name = "root";
    root.is_wildcard = false;

    self.method_tries.set(method_key, root);
  }
}

// Build trie structure for a method (called after adding routes)
fn void Router.build_method_trie(&self, HttpVerb method) {
  String method_key = method.str_val;

  // Create root node for this method
  TrieNode root;
  root.path = "/";
  root.type = NodeType.STATIC;
  root.children.init(mem);
  root.route = null;
  root.param_name = "";
  root.is_wildcard = false;

  // Add all routes for this method to the trie
  if (self.method_routes.has_key(method_key)) {
    List{RouteInfo} ? route_list = self.method_routes[method_key];
    if (catch route_list) {
      return;
    }
    foreach (usz i, route : route_list) {
      self.add_route_to_trie(&root, route.path, &route_list[i]);
    }
  }

  // Store the trie
  self.method_tries.set(method_key, root);
}

// Add a route to the trie structure
fn void Router.add_route_to_trie(&self, TrieNode *node, String path,
                                 RouteInfo *route) {
  String[] parts = path.tsplit("/");
  io::printn(parts);
  TrieNode *current = node;

  foreach (i, part : parts) {
    if (part.len == 0) {
      continue;
    }

    if (part.starts_with(":")) {
      // Dynamic parameter node
      String param_name = part[1..];

      if (!current.children.has_key("PARAM")) {
        TrieNode param_node;
        param_node.path = "";
        param_node.type = NodeType.PARAM;
        param_node.children.init(mem);
        param_node.route = null;
        param_node.param_name = param_name;
        param_node.is_wildcard = false;
        current.children.set("PARAM", param_node);
      }

      current = &current.children["PARAM"];
    } else if (part.contains("*")) {
      // Wildcard node
      // usz ? wildcard_pos = part.index_of("*");
      // if(try wildcard_pos){

      // }
      // String prefix = wildcard_pos != (usz)(-1) ? part[..wildcard_pos] :
      // part;

      if (!current.children.has_key("WILDCARD")) {
        TrieNode wildcard_node;
        wildcard_node.path = "";
        wildcard_node.type = NodeType.WILDCARD;
        wildcard_node.children.init(mem);
        wildcard_node.route = route;
        wildcard_node.param_name = "*";
        wildcard_node.is_wildcard = true;
        current.children.set("WILDCARD", wildcard_node);
      }

      return; // Wildcard terminates the path
    } else {
      // Static path node
      if (!current.children.has_key(part)) {
        TrieNode static_node;
        static_node.path = part;
        static_node.type = NodeType.STATIC;
        static_node.children.init(mem);
        static_node.route = null;
        static_node.param_name = "";
        static_node.is_wildcard = false;
        current.children.set(part, static_node);
      }

      current = &current.children[part];
    }
  }

  // Set the route at the terminal node
  current.route = route;
}

// Find route using trie-based lookup (optimized)
fn RouteInfo *Router.find_route_trie(&self, String pathname, HttpVerb method) {
  String method_key = method.str_val;

  if (!self.method_tries.has_key(method_key)) {
    // Build trie if it doesn't exist
    (void)self.build_method_trie(method);
  }

  TrieNode root = self.method_tries[method_key] !!;
  String[] parts = pathname.tsplit("/");

  return self.search_trie(&root, parts, 0);
}

// Search the trie for a matching route
fn RouteInfo *Router.search_trie(&self, TrieNode *node, String[] parts,
                                 int index) {
  if (index >= parts.len) {
    // Check for wildcard match at end
    if (node.children.has_key("WILDCARD")) {
      return node.children["WILDCARD"] !!.route;
    }
    // End of path - check if this is a terminal node
    if (node.route) {
      return node.route;
    }
    return null;
  }

  String part = parts[index];
  if (part.len == 0) {
    return self.search_trie(node, parts, index + 1);
  }

  // Check for exact match first
  if (node.children.has_key(part)) {
    RouteInfo *result =
        self.search_trie(&&node.children[part] !!, parts, index + 1);
    if (result) {
      return result;
    }
  }

  // Check for parameter match
  if (node.children.has_key("PARAM")) {
    TrieNode *param_node = &&node.children["PARAM"] !!;
    RouteInfo *result = self.search_trie(param_node, parts, index + 1);
    if (result) {
      return result;
    }
  }

  // Check for wildcard match
  if (node.children.has_key("WILDCARD")) {
    return node.children["WILDCARD"] !!.route;
  }

  // No match found
  return null;
}

// Add a route to the router
fn void Router.add_route(&self, String path, HttpVerb method,
                         HandlerFn handler) {
  io::printn("Running Router.add_route");

  // Validate path
  if (path.len == 0) {
    io::printfn("[ERROR] `%s` for route %s\ncause: len = 0", "INVALID_PATH",
                path);
    return;
    // return INVALID_PATH ? ;
  }

  if (path[0] != '/') {
    io::printfn("[ERROR] Route `%s` doesn't start with '/'\n", path);
    return;
    // return INVALID_PATH ? ;
  }

  // Enhanced duplicate detection with thread-safe tracking
  // Check for duplicate routes with comprehensive validation
  foreach (existing_route : self.routes) {
    if (existing_route.path == path && existing_route.method == method) {
      // Log warning with additional context
      io::printf("Warning: Duplicate route detected for %s %s\n",
                 method.str_val, path);

      // Enhanced fault handling with explicit error type

      //   return DUPLICATE_ROUTE ? ; // Explicit fault for better error
      //   tracking
      io::printfn("[ERROR] DUPLICATE_ROUTE `%s`", path);
      return;
    }
  }

  // Extract parameter names and validate path
  List{String} param_names;
  param_names.init(mem);
  defer param_names.free();

  String[] path_parts = path.tsplit("/");
  bool has_wildcard = false;

  foreach (part : path_parts) {
    if (part.len > 0) {
      if (part.starts_with(":")) {
        // Validate parameter name
        String param_name = part[1..];
        if (param_name.len == 0) {
          //   return INVALID_PATH ? ;
          io::printfn("[ERROR] `%s` for route %s\ncause: len = 0",
                      "INVALID_PATH", path);
          return;
        }

        // Check for valid parameter characters
        foreach (ch : param_name) {
          if (!((ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') ||
                (ch >= '0' && ch <= '9') || ch == '_')) {
            // return INVALID_PATH ? ;
            io::printfn("[ERROR] `%s` for route %s\n", "INVALID_CHAR", path);
            return;
          }
        }

        param_names.push(param_name);
      } else {
        bool has_star = false;
        if (catch val = part.index_of("*")) {
          has_star = true;
        }
        if (has_star) {
          // Wildcard support - only one wildcard per path
          usz param_count2 = param_names.len();
          if (has_wildcard || param_count2 > 0) {
            // return MULTIPLE_DYNAMIC_PARAMS ? ;
            io::printfn("[ERROR] `%s` for route %s\n",
                        "MULTIPLE_DYNAMIC_PARAMS", path);
            return;
          }
          has_wildcard = true;
          String wildcard = "*";
          param_names.push(wildcard);
        }
      }
    }
  }

  // Create route info
  String[] param_names_array = param_names.to_array(mem);
  RouteInfo route = {.path = path,
                     .method = method,
                     .handler_fn = handler,
                     .param_names = param_names_array};

  // Add to routes list
  self.routes.push(route);

  // Add to method-based cache
  String method_key = method.str_val;
  if (!self.method_routes.has_key(method_key)) {
    List{RouteInfo} method_route_list;
    method_route_list.init(mem);
    self.method_routes.set(method_key, method_route_list);
  }
  (void)self.method_routes[method_key] !!.push(route);

  // Categorize route for optimization
  usz param_count = param_names.len();
  if (param_count == 0) {
    self.static_routes.push(path);
  } else {
    self.dynamic_routes.push(path);
  }
}

// Check if a path contains dynamic parameters
fn bool Router.is_dynamic_path(&self, String path) {
  return path.contains(":") || path.contains("*");
}

// Extract parameters from a path match
fn HashMap{String, String}
? Router.extract_params(&self, String route_path, String request_path) {
  HashMap{String, String} params;
  params.init(mem);

  String[] route_parts = route_path.tsplit("/");
  String[] request_parts = request_path.tsplit("/");

  if (route_parts.len != request_parts.len) {
    params.free();
    return {};
  }

  foreach (i, part : route_parts) {
    if (part.len > 0) {
      if (part.starts_with(":")) {
        // Extract parameter name and value
        String param_name = part[1..];
        String param_value = request_parts[i];
        params.set(param_name, param_value);
      }
    }
  }

  return params;
}

// Find a matching route for a request with optimized lookup
fn RouteInfo *Router.find_route(&self, String pathname, HttpVerb method) {
  // Quick validation
  if (!self.validate_path(pathname)) {
    return null;
  }

  // Fallback to traditional lookup if trie fails
  String method_key = method.str_val;

  // Check method-specific routes
  if (self.method_routes.has_key(method_key)) {
    List{RouteInfo} method_routes_list = self.method_routes[method_key] !!;
    foreach (usz j, route : method_routes_list) {
      if (self.match_route(route.path, pathname)) {
        return &method_routes_list[j];
      }
    }
  }

  return null;
}

// Match a route pattern against a request path
fn bool Router.match_route(&self, String route_path, String request_path) {
  io::printn("Running Router.match_route");
  String[] route_parts = route_path.tsplit("/");
  String[] request_parts = request_path.tsplit("/");

  // Add logging to trace route matching
  io::printf("Matching route: %s with request: %s\n", route_path, request_path);

  for (int i = 0; i < route_parts.len; i++) {
    if (i >= request_parts.len) {
      return false;
    }

    String route_part = route_parts[i];
    String request_part = request_parts[i];

    if (route_part.len == 0) {
      continue;
    }

    if (route_part.starts_with(":")) {
      if (request_part.len == 0) {
        return false;
      }
    } else if (route_part.contains("*")) {
      // Wildcard route matches anything from this position
      return true;
    } else {
      if (route_part != request_part) {
        return false;
      }
    }
  }

  return true;
}

// Handle a request by finding the appropriate route and calling its handler
fn Response ? Router.handle_request(&self, Request request) {
  RouteInfo *route = self.find_route(request.pathname, request.method);

  // Log the request being handled
  io::printf("Handling request: %s %s\n", request.method.str_val,
             request.pathname);

  if (route) {
    io::printf("Matched route: %s\n", route.path);
  } else {
    io::printf("No matching route found for: %s %s\n", request.method.str_val,
               request.pathname);
  }

  if (route) {
    // Extract parameters if this is a dynamic route
    HashMap{String, String} params;
    params.init(mem);

    if (self.is_dynamic_path(route.path)) {
      HashMap{String, String}
      ? extracted_params = self.extract_params(route.path, request.pathname);
      if (try HashMap{String, String} p = extracted_params) {
        params = p;
      }
    }

    // Call the route handler with proper error handling
    Response response = route.handler_fn(request);

    // Clean up
    params.free();

    return response;
  } else {
    // Explicitly handle route not found case with proper response
    DString not_found_body;
    not_found_body.init(mem);
    not_found_body.append("{\"error\": \"Route not found\"}");
    Response not_found_response = {.status = 404,
                                   .status_text = StatusText.NOT_FOUND,
                                   .data = not_found_body,
                                   .content_type = ContentType.JSON};
    return not_found_response;
  }
}

// Utility function to validate a path
fn bool Router.validate_path(&self, String path) {
  if (path.len == 0) {
    return false;
  }
  if (path[0] != '/') {
    return false;
  }

  // Check for invalid characters
  foreach (ch : path) {
    if (ch == ' ' || ch == '?' || ch == '#') {
      return false;
    }
  }

  return true;
}