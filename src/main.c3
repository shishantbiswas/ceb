module main;
import std::io;

import ceb;
import ceb::enums;

fn Response homeHandler(Request req) { return utils::read_file("index.html"); }

fn Response aboutHandler(Request req) { return utils::read_file("about.html"); }

fn int main() {
  Server server;
  server.init();

  defer server.start();

  server
      .get("/test/*", (HandlerFn)&aboutHandler);

  io::printf("%d handler were registered\n", server.routes.len());
  io::printf("%d middleware were registered\n", server.middleware.len());

  return 0;
}
