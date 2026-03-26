module main;
import std::io;
import std::collections::map;

import ceb;
import ceb::enums;

fn Response userHandler(Request req) {
  DString body;
  body.init(mem);
  body.append("User ID: ");
  if (req.params.has_key("id")) {
    body.append(req.params["id"] !!);
  } else {
    body.append("unknown");
  }
  return {.status = 200,
          .status_text = StatusText.OK,
          .data = body,
          .content_type = ContentType.TXT};
}

fn Response apiHandler(Request req) {
  DString body;
  body.init(mem);
  body.append("API Catch-all");
  return {.status = 200,
          .status_text = StatusText.OK,
          .data = body,
          .content_type = ContentType.TXT};
}

fn int main() {
  Server server;
  server.init();

  defer server.start();

  server
      .get("/heyo",
           fn(Request req) => (Response){.status = 200,
                                          .status_text = StatusText.OK,
                                          .data = dstring::temp("Hello World"),
                                          .content_type = ContentType.TXT})
      .get("/",
           fn(Request req) => (Response)utils::read_file("public/index.html"))
      .get("/about",
           fn(Request req) => (Response)utils::read_file("public/about.html"))
      .get("/user/:id", (HandlerFn)&userHandler)
      .get("/api/proxy/*", (HandlerFn)&apiHandler);

  io::printn("Server initialized");

  return 0;
}
