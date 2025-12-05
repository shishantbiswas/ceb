module main;
import std::io;

import ceb;
import ceb::enums;

fn Response homeHandler(Request req) {
  DString html_data;
  html_data.init(&allocator::LIBC_ALLOCATOR, 256);
  defer html_data.free();

  @pool_init(&allocator::LIBC_ALLOCATOR, 512) {
    char[] ? file = file::load(&allocator::LIBC_ALLOCATOR, "index.html");
    if (catch excuse = file)
    {
      html_data.append("Internal Server Error");
      return {
      .data = html_data,
      .status = 500,
      };
    }
    html_data.append(file);
  };
  return {
      .data = html_data,
      .content_type = ContentType.HTML,
      .status = 200,
  };
}

fn Response aboutHandler(Request req) {
  DString html_data;
  html_data.init(&allocator::LIBC_ALLOCATOR, 256);
  defer html_data.free();

  @pool_init(&allocator::LIBC_ALLOCATOR, 512) {
    char[] ? file = file::load(&allocator::LIBC_ALLOCATOR, "about.html");
    if (catch excuse = file)
    {
      html_data.append("Internal Server Error");
      return {
      .data = html_data,
      .content_type = ContentType.TXT,
      .status = 500,
      };
    }
    html_data.append(file);
  };
  return {
      .data = html_data,
      .content_type = ContentType.TXT,
      .status = 200,
  };
}

fn void logger(MiddlewareCtx ctx){
  io::printf("Middleware Request: %s at path '%s'\n",ctx.request_type.str_val, ctx.pathname);
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
  server.routes.init(&allocator::LIBC_ALLOCATOR);
  server.middleware.init(&allocator::LIBC_ALLOCATOR);

  defer {
    server.start();
    server.routes.free();
    server.middleware.free();
  };

  // Register middleware
  // Could be inlined as well like 
  /*
      server.use({
        .name = "logger",
        .middleware_fn = (MiddlewareFn)&logger,
        .invocation = MiddlewareInvocation.AFTER,
      });
   */
  server.use(loggerMiddleware());

  // Register routes
  server
    .get("/", (HandlerFn)&homeHandler)
    .post("/", (HandlerFn)&homeHandler)
    .get("/about", (HandlerFn)&aboutHandler);

  io::printf("%d handler were registered\n", server.routes.len());
  io::printf("%d middleware were registered\n", server.middleware.len());

  return 0;
}
