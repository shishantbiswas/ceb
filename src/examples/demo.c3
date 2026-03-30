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
	// io::printn(req.headers.get("host")!!);
	foreach (header: req.headers.tkeys()){
	  io::printn(header);
	}

	return { .status = 200, .status_text = StatusText.OK, .data = body, .content_type = ContentType.TXT };
}

// pass any config options you need for your custom middlware
fn Middleware logger(){
	return (Middleware){
		.name = "static_serve",
		.procedure = fn (MiddlewareCtx ctx)=>(void)io::printf("[LOGGER]: %s at path '%s'\n",ctx.request.method.str_val ,ctx.request.pathname),
	};
}


fn int main()
{
	Server server;
	server.init();

	defer server.start("0.0.0.0", 3000);

	server.use(logger());

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
		.get("/output.css",  fn (Request req) => utils::read_file("docs/output.css"))
		.get("/user/:id",    &userHandler)
		.get("/api/proxy/*", &apiHandler)
		.get("/booboo",      &booboo)
		.head("/booboo",      &booboo);

	io::printn("Server initialized");
	io::printf("%d handler were registered\n", server.router._routes_storage.len());
	io::printf("%d middleware were registered\n", server.middleware.len());

	return 0;
}
