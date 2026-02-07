module main;
import std::io;
import std::collections::map;

import ceb;
import ceb::enums;

fn Response homeHandler(Request req) { return utils::read_file("index.html"); }

fn Response aboutHandler(Request req) { return utils::read_file("about.html"); }

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
      .get("/",
           fn(Request req) => (Response){.status = 200,
                                          .status_text = StatusText.OK,
                                          .data = dstring::temp("Hello World"),
                                          .content_type = ContentType.TXT})
      .get("/about", (HandlerFn)&aboutHandler)
      .get("/user/:id", (HandlerFn)&userHandler)
      .get("/api/proxy/*", (HandlerFn)&apiHandler);

  io::printn("Server initialized");

  return 0;
}
