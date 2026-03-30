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

fn Response booboo(Request req)
{
	DString body;
	body.tinit();
	req.body();
	body.append("Tell'em kendrick did it");
  // io::printn(req.headers.headers.get("host")!!);
  // foreach (header: req.headers.headers.tkeys()){
  //   io::printn(header);
  // }

	return { .status = 200, .status_text = StatusText.OK, .data = body, .content_type = ContentType.TXT };
}

fn int main()
{
	Server server;
	server.init();

	defer server.start("127.0.0.1", 3000);

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
    .get("/api/proxy/*", &apiHandler)
    .get("/booboo",      &booboo);

	io::printn("Server initialized");

	return 0;
}
