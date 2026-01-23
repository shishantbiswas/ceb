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
    METHOD_NOT_ALLOWED, DUPLICATE_ROUTE, INVALID_CHAR;

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
  String[] param_names;
}

// Trie Node for optimized route lookup
struct TrieNode {
  String segment;
  HashMap{String, TrieNode} children; // Static path children
  TrieNode *param_child;              // Single dynamic parameter child
  TrieNode *wildcard_child;           // Single wildcard child
  RouteInfo *route;  // Route definition if this is a matching leaf
  String param_name; // Name of the parameter (e.g. "id")
}

fn void TrieNode.free(TrieNode *self) {
  // Recursively free children in the map
  foreach (key : self.children.keys(tmem)) {
    self.children[key] !!.free();
  }
  self.children.free();

  if (self.param_child) {
    self.param_child.free();
    mem::free(self.param_child);
    self.param_child = null;
  }
  if (self.wildcard_child) {
    self.wildcard_child.free();
    mem::free(self.wildcard_child);
    self.wildcard_child = null;
  }
}

struct Router {
  HashMap{String, TrieNode} method_tries; // Root nodes for each method
  List{RouteInfo} _routes_storage;        // Owns the RouteInfo memory
}

// Initialize a new router
fn Router *Router.init(&self) {
  self.method_tries.init(mem);
  self._routes_storage.init(mem);
  return self;
}

// Free router resources
fn void Router.free(&self) {
  foreach (key : self.method_tries.keys(tmem)) {
    self.method_tries[key] !!.free();
  }
  self.method_tries.free();
  self._routes_storage.free();
}

// Internal helper to get or create a method root
fn TrieNode *Router.get_or_create_root(&self, HttpVerb method) {
  String method_key = method.str_val;
  if (!self.method_tries.has_key(method_key)) {
    TrieNode root;
    root.segment = "/";
    root.children.init(mem);
    root.param_child = null;
    root.wildcard_child = null;
    root.route = null;

    self.method_tries.set(method_key, root);
  }
  return &self.method_tries[method_key];
}

// Add a route to the router
fn void Router.add_route(&self, String path, HttpVerb method,
                         HandlerFn handler) {
  // Basic validation
  if (path.len == 0 || path[0] != '/') {
    io::printfn("[ERROR] Invalid path format: `%s`", path);
    return;
  }

  TrieNode *current = self.get_or_create_root(method);

  // Parse path and extract param names
  String[] parts = path.tsplit("/");
  List{String} param_names;
  param_names.init(mem);
  defer param_names.free();

  foreach (part : parts) {
    if (part.len == 0) {
      continue;
    }

    if (part.starts_with(":")) {
      // Dynamic Parameter
      String p_name = part[1..];
      if (p_name.len == 0) {
        io::printfn("[ERROR] Empty parameter name in path: %s", path);
        return;
      }
      param_names.push(p_name);

      if (!current.param_child) {
        TrieNode *node = mem::new (TrieNode);
        node.segment = part;
        node.children.init(mem);
        node.param_name = p_name;
        current.param_child = node;
      } else {
        if (current.param_child.param_name != p_name) {
          io::printfn(
              "[WARNING] Parameter name mismatch at same level: %s vs %s",
              current.param_child.param_name, p_name);
        }
      }
      current = current.param_child;

    } else if (part == "*") {
      // Wildcard
      if (!current.wildcard_child) {
        TrieNode *node = mem::new (TrieNode);
        node.segment = "*";
        node.children.init(mem);
        current.wildcard_child = node;
      }
      current = current.wildcard_child;
      break;

    } else {
      // Static
      if (!current.children.has_key(part)) {
        TrieNode node;
        node.segment = part;
        node.children.init(mem);
        current.children.set(part, node);
      }
      current = &current.children[part];
    }
  }

  if (current.route) {
    io::printfn("[WARNING] Duplicate route path: %s %s", method.str_val, path);
    return;
  }

  // Store route info
  String[] p_names = param_names.to_array(mem);
  RouteInfo route = {.path = path,
                     .method = method,
                     .handler_fn = handler,
                     .param_names = p_names};

  self._routes_storage.push(route);

  // Use stable pointer for Trie
  RouteInfo *stable_route = mem::new (RouteInfo);
  *stable_route = route;
  current.route = stable_route;
}

// Search helper
fn RouteInfo *Router.search_trie(&self, TrieNode *node, String[] parts,
                                 int index, List{String} * param_values) {
  // If we reached end of path parts
  if (index >= parts.len) {
    // If this node is terminal, match!
    if (node.route) {
      return node.route;
    }

    // Wildcard child can match empty rest at end of path if intended (e.g.
    // /api/* matches /api/) But usually * requires at least one char or
    // segment? Depends on spec. Let's assume loose matching for * at end.
    if (node.wildcard_child && node.wildcard_child.route) {
      return node.wildcard_child.route;
    }

    return null;
  }

  String part = parts[index];
  if (part.len == 0) {
    // Skip empty parts (doubled slashes)
    return self.search_trie(node, parts, index + 1, param_values);
  }

  // 1. Static Exact Match
  if (node.children.has_key(part)) {
    RouteInfo *res =
        self.search_trie(&node.children[part], parts, index + 1, param_values);
    if (res) {
      return res;
    }
  }

  // 2. Dynamic Param Match
  if (node.param_child) {
    param_values.push(part);
    RouteInfo *res =
        self.search_trie(node.param_child, parts, index + 1, param_values);
    if (res) {
      return res;
    }
    // Backtrack
    (void)param_values.pop();
  }

  // 3. Wildcard Match
  if (node.wildcard_child) {
    if (node.wildcard_child.route) {
      return node.wildcard_child.route;
    }
  }

  return null;
}

// Find route public API (used by ceb.c3)
fn RouteInfo *Router.find_route(&self, String pathname, HttpVerb method) {
  if (!self.method_tries.has_key(method.str_val)) {
    return null;
  }

  TrieNode *root = &self.method_tries[method.str_val];
  String[] parts = pathname.tsplit("/");

  List{String} param_vals;
  param_vals.init(tmem); // Use temp memory as we don't need values here
  // defer param_vals.free(); // tmem is freed automatically usually, or we can
  // free. List.init(tmem) doesn't need explicit free if scope is small, but
  // safer to match init. But since it's tmem, we can skip free or free it.

  return self.search_trie(root, parts, 0, &param_vals);
}

// Handle request
fn Response ? Router.handle_request(&self, Request request) {
  if (!self.method_tries.has_key(request.method.str_val)) {
    DString not_found_body;
    not_found_body.init(mem);
    not_found_body.append("{\"error\": \"Route not found\"}");
    return {.status = 404,
            .status_text = StatusText.NOT_FOUND,
            .data = not_found_body,
            .content_type = ContentType.JSON};
  }

  TrieNode *root = &self.method_tries[request.method.str_val];
  String[] parts = request.pathname.tsplit("/");

  List{String} param_vals;
  param_vals.init(mem);
  defer param_vals.free();

  RouteInfo *route = self.search_trie(root, parts, 0, &param_vals);

  if (route) {
    // Populate params
    if (route.param_names.len > 0 && param_vals.len() > 0) {
      // Zip
      for (usz i = 0; i < route.param_names.len && i < param_vals.len(); i++) {
        request.params.set(route.param_names[i], param_vals[i]);
      }
    }

    return route.handler_fn(request);
  } else {
    DString not_found_body;
    not_found_body.init(mem);
    not_found_body.append("{\"error\": \"Route not found\"}");
    return {.status = 404,
            .status_text = StatusText.NOT_FOUND,
            .data = not_found_body,
            .content_type = ContentType.JSON};
  }
}

// Validation helper (simplified)
fn bool Router.validate_path(&self, String path) {
  return path.len > 0 && path[0] == '/';
}