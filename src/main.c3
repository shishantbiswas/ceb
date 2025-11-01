module main;
import std::io;

import ceb;
import ceb::enums;

fn Response ? homeHandler(Request req) {
  DString html_data;
  html_data.init(&allocator::LIBC_ALLOCATOR, 256);
  defer html_data.free();

  @pool_init(&allocator::LIBC_ALLOCATOR, 512) {
    char[] file = file::load(&allocator::LIBC_ALLOCATOR, "index.html") !;
    html_data.append(file);
  };
  return {
      .data = html_data,
      .content_type = ContentType.HTML,
      .status = 200,
  };
}

fn int main() {
  Server server;
  server.routes.init(&allocator::LIBC_ALLOCATOR);

  server
    .get("/", (HandlerFn)&homeHandler)
    .post("/", (HandlerFn)&homeHandler);

  io::printf("%d handler were registered\n", server.routes.len());
  server.start();

  return 0;
}
