module ceb;

fn Server *Server.get(&this, String path, HandlerFn handler_fn) {
  Route route = {
      .path = path,
      .method = HttpVerb.GET,
      .handler_fn = handler_fn,
  };
  this.routes.push(route);
  return this;
}

fn Server *Server.post(&this, String path, HandlerFn handler_fn) {
  Route route = {
      .path = path,
      .method = HttpVerb.POST,
      .handler_fn = handler_fn,
  };
  this.routes.push(route);
  return this;
}

fn Server *Server.put(&this, String path, HandlerFn handler_fn) {
  Route route = {
      .path = path,
      .method = HttpVerb.PUT,
      .handler_fn = handler_fn,
  };
  this.routes.push(route);
  return this;
}

fn Server *Server.patch(&this, String path, HandlerFn handler_fn) {
  Route route = {
      .path = path,
      .method = HttpVerb.PATCH,
      .handler_fn = handler_fn,
  };
  this.routes.push(route);
  return this;
}

fn Server *Server.delete(&this, String path, HandlerFn handler_fn) {
  Route route = {
      .path = path,
      .method = HttpVerb.DELETE,
      .handler_fn = handler_fn,
  };
  this.routes.push(route);
  return this;
}