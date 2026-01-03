module main;
import std::io;

import ceb;
import ceb::enums;

fn Response homeHandler(Request req) {
  return utils::read_file("index.html");
}

fn Response aboutHandler(Request req) {
  return utils::read_file("about.html");
}

fn void logger(MiddlewareCtx ctx) {
  io::printf("Logger: %s at path '%s'\n", ctx.request_type.str_val,
             ctx.pathname);
}

fn Middleware loggerMiddleware() {
  return {
      .name = "logger",
      .middleware_fn = (MiddlewareFn)&logger,
      .invocation = MiddlewareInvocation.AFTER,
  };
}

fn int main() {
  Server server;
  server.init();

  defer server.start();

  // Register routes
  server.get("/", (HandlerFn)&homeHandler)
      .post("/", (HandlerFn)&homeHandler)
      .get("/about", (HandlerFn)&aboutHandler)
      .post("/about", (HandlerFn)&aboutHandler);

  io::printf("%d handler were registered\n", server.routes.len());
  io::printf("%d middleware were registered\n", server.middleware.len());

  return 0;
}
