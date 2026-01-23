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





fn Server *Server.get(&self, String path, HandlerFn handler) {
  self.router.add_route(path, HttpVerb.GET, handler);
  return self;
}

fn Server *Server.post(&self, String path, HandlerFn handler) {
  self.router.add_route(path, HttpVerb.POST, handler);
  return self;
}

fn Server *Server.put(&self, String path, HandlerFn handler) {
  self.router.add_route(path, HttpVerb.PUT, handler);
  return self;
}

fn Server *Server.patch(&self, String path, HandlerFn handler) {
  self.router.add_route(path, HttpVerb.PATCH, handler);
  return self;
}

fn Server *Server.delete(&self, String path, HandlerFn handler) {
  self.router.add_route(path, HttpVerb.DELETE, handler);
  return self;
}

fn Server *Server.options(&self, String path, HandlerFn handler) {
  self.router.add_route(path, HttpVerb.OPTIONS, handler);
  return self;
}

fn Server *Server.head(&self, String path, HandlerFn handler) {
  self.router.add_route(path, HttpVerb.HEAD, handler);
  return self;
}

fn Server *Server.connect(&self, String path, HandlerFn handler) {
  self.router.add_route(path, HttpVerb.CONNECT, handler);
  return self;
}

fn Server *Server.trace(&self, String path, HandlerFn handler) {
  self.router.add_route(path, HttpVerb.TRACE, handler);
  return self;
}
