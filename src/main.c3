module main;
import std::io;
import std::collections::map;

import ceb;
import ceb::enums;

fn Response userHandler(Request req)
{
	DString body;
	body.init(mem);
	body.append("User ID: ");
	if (req.params.has_key("id"))
	{
		body.append(req.params["id"]!!);
	}
	else
	{
		body.append("unknown");
	}
	return { .status = 200, .status_text = StatusText.OK, .data = body, .content_type = ContentType.TXT };
}

fn Response apiHandler(Request req)
{
	DString body;
	body.init(mem);
	body.append("API Catch-all");
	return { .status = 200, .status_text = StatusText.OK, .data = body, .content_type = ContentType.TXT };
}

fn int main()
{
	Server server;
	server.init();

	defer server.start();

	server
    .get("/heyo",
      fn (
        Request req
      ) => {
        .status = 200,
        .status_text = StatusText.OK,
        .data = dstring::temp("Hello World"),
        .content_type = ContentType.TXT
      }
    )
    // casting is optional from compiler version 0.7.10
    .get("/",            fn (Request req) => utils::read_file("docs/index.html"))
    .get("/about",       fn (Request req) => utils::read_file("docs/about.html"))
    .get("/favicon.png", fn (Request req) => utils::read_file("docs/assets/favicon.png"))
    .get("/user/:id",    &userHandler)
    .get("/api/proxy/*", &apiHandler);

	io::printn("Server initialized");

	return 0;
}
