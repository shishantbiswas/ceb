module main;
import std::io;
import std::collections::map;

import ceb;
import ceb::enums;

fn Response userHandler(Request req, Server *server)
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

fn Response apiHandler(Request req, Server *server)
{
	DString body;
	body.init(mem);
	body.append("API Catch-all");
	io::printn(req.pathname);
	return { .status = 200, .status_text = StatusText.OK, .data = body, .content_type = ContentType.TXT };
}

fn Response booboo(Request req, Server *server)
{
	DString body;
	body.tinit();
	// req.body(); // req.body().json(), or req.body().form_data() or req.body() for raw binary
	// maybe a validator is in need to check sql injections and such attacks
	Response response = {
		.status = 200,
		.status_text = StatusText.OK, 
		.content_type = ContentType.TXT
	};
	response.headers.tinit();
	response.headers.set("token", "token_value");

	body.append("Tell'em kendrick did it");
	// io::printn(req.headers.get("host")!!);
	// foreach (header: req.headers.tkeys()){
	//   io::printn(header);
	// }
	response.data = body;
	return response;
}


fn int main()
{
	Server server;
	server.init();

	defer server.start("0.0.0.0", 3000);

	server.use(utils::logger());

	server
		// .get("/booboo2", fn (
		// 	Request req
		// ) => {
		// 	.status = 200,
		// 	.status_text = StatusText.OK,
		// 	.data = dstring::temp("Hello World"),
		// 	.content_type = ContentType.TXT
		// })
		.get("/heyo",
		fn (
			Request req,
			Server *server
		) => {
			.status = 200,
			.status_text = StatusText.OK,
			.data = dstring::temp("Hello World"),
			.content_type = ContentType.TXT
		}
		)
		// casting is optional from compiler version 0.7.10
		.get("/",            fn (Request req, Server *server) => utils::read_file(server, "docs/index.html"))
		.get("/about",       fn (Request req, Server *server) => utils::read_file(server, "docs/about.html"))
		.get("/favicon.png", fn (Request req, Server *server) => utils::read_file(server, "docs/assets/favicon.png"))
		.get("/output.css",  fn (Request req, Server *server) => utils::read_file(server, "docs/output.css"))
		.get("/user/:id",    &userHandler)
		.get("/api/proxy/*", &apiHandler)
		.get("/booboo",      &booboo)
		.head("/booboo",      &booboo);

	io::printn("Server initialized");
	io::printf("%d handler were registered\n", server.router._routes_storage.len());
	io::printf("%d middleware were registered\n", server.middleware.len());

	return 0;
}
