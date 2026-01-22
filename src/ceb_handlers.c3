module ceb;

// fn Server *Server.get(&this, String path, HandlerFn handler_fn) {
//   Route route = {
//       .path = path,
//       .method = HttpVerb.GET,
//       .handler_fn = handler_fn,
//   };
//   this.routes.push(route);
//   return this;
// }

// fn Server *Server.post(&this, String path, HandlerFn handler_fn) {
//   Route route = {
//       .path = path,
//       .method = HttpVerb.POST,
//       .handler_fn = handler_fn,
//   };
//   this.routes.push(route);
//   return this;
// }

// fn Server *Server.put(&this, String path, HandlerFn handler_fn) {
//   Route route = {
//       .path = path,
//       .method = HttpVerb.PUT,
//       .handler_fn = handler_fn,
//   };
//   this.routes.push(route);
//   return this;
// }

// fn Server *Server.patch(&this, String path, HandlerFn handler_fn) {
//   Route route = {
//       .path = path,
//       .method = HttpVerb.PATCH,
//       .handler_fn = handler_fn,
//   };
//   this.routes.push(route);
//   return this;
// }

// fn Server *Server.delete(&this, String path, HandlerFn handler_fn) {
//   Route route = {
//       .path = path,
//       .method = HttpVerb.DELETE,
//       .handler_fn = handler_fn,
//   };
//   this.routes.push(route);
//   return this;
// }





fn void? Server.get(&self, String path, HandlerFn handler) {
  self.router.add_route(path, HttpVerb.GET, handler)!!;
}

fn void? Server.post(&self, String path, HandlerFn handler) {
  self.router.add_route(path, HttpVerb.POST, handler)!!;
}

fn void? Server.put(&self, String path, HandlerFn handler) {
  self.router.add_route(path, HttpVerb.PUT, handler)!!;
}

fn void? Server.patch(&self, String path, HandlerFn handler) {
  self.router.add_route(path, HttpVerb.PATCH, handler)!!;
}

fn void? Server.delete(&self, String path, HandlerFn handler) {
  self.router.add_route(path, HttpVerb.DELETE, handler)!!;
}

fn void? Server.options(&self, String path, HandlerFn handler) {
  self.router.add_route(path, HttpVerb.OPTIONS, handler)!!;
}

fn void? Server.head(&self, String path, HandlerFn handler) {
  self.router.add_route(path, HttpVerb.HEAD, handler)!!;
}

fn void? Server.connect(&self, String path, HandlerFn handler) {
  self.router.add_route(path, HttpVerb.CONNECT, handler)!!;
}

fn void? Server.trace(&self, String path, HandlerFn handler) {
  self.router.add_route(path, HttpVerb.TRACE, handler)!!;
}
