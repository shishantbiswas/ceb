module main;
import std::io;
import std::collections::map;

import ceb;
import ceb::enums;

fn void userHandler(Context ctx)
{
	DString body;
	body.init(mem);
	body.append("User ID: ");
	if (ctx.req.params.has_key("id"))
	{
		body.append(ctx.req.params["id"]!!);
	}
	else
	{
		body.append("unknown");
	}
	{
		Response res = { .status = 200, .status_text = StatusText.OK, .data = body, .content_type = ContentType.TXT };
		res.headers.tinit();
		ctx.response(res);
	}
	ctx.next.call();
}

fn void apiHandler(Context ctx)
{
	DString body;
	body.init(mem);
	body.append("API Catch-all");
	io::printn(ctx.req.pathname);
	{
		Response res = { .status = 200, .status_text = StatusText.OK, .data = body, .content_type = ContentType.TXT };
		res.headers.tinit();
		ctx.response(res);
	}
	ctx.next.call();
}

fn void booboo(Context ctx)
{
	DString body;
	body.tinit();
	
	Response response = {
		.status = 200,
		.status_text = StatusText.OK, 
		.content_type = ContentType.TXT
	};
	response.headers.tinit();

	body.append("Tell'em kendrick did it");
	
	response.data = body;
	ctx.response(response);
	ctx.next.call();
}


fn int main()
{
	Server server;
	server.init();

	defer server.start("0.0.0.0", 3000);

	// server.use(utils::logger());

	server
		.get("/heyo",
		fn (Context ctx) {
			Response res = {
				.status = 200,
				.status_text = StatusText.OK,
				.data = dstring::temp("Hello World"),
				.content_type = ContentType.TXT
			};
			res.headers.tinit();
			ctx.response(res);
			ctx.next.call();
		}
		)
		// casting is optional from compiler version 0.7.10
		.get("/",            fn (Context ctx) => utils::read_file(ctx.server, "docs/index.html", ctx))
		.get("/about",       fn (Context ctx) => utils::read_file(ctx.server, "docs/about.html", ctx))
		.get("/favicon.svg", fn (Context ctx) => utils::read_file(ctx.server, "docs/assets/favicon.svg", ctx))
		.get("/output.css",  fn (Context ctx) => utils::read_file(ctx.server, "docs/output.css", ctx))
		.get("/user/:id",    &userHandler)
		.get("/api/proxy/*", &apiHandler)
		.get("/booboo",      &booboo)
		.head("/booboo",     &booboo);

	io::printn("Server initialized");
	io::printf("%d handler were registered\n", server.router._routes_storage.len());
	io::printf("%d middleware were registered\n", server.middleware.len());

	return 0;
}
