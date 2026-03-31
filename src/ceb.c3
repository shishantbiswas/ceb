module ceb;
// Std imports
import std::collections::list;
import std::net;
import std::net::tcp;
import std::thread;
import std::collections::map;
import std::core::mem::allocator;
import std::core::string;
import std::io::file;
import std::time;

// Ceb imports
import ceb::enums;
import ceb::router;
import ceb::parser;
import ceb::utils;
import ceb::middleware;

// Async (uv) imports
import async::event_loop;
import async::tcp;

struct Server
{
	Router router;
	List{Middleware} middleware;
	TcpServerSocket server;
	String host;
	event_loop::EventLoop loop;
	uint port;
	uint backlog;
}

struct Response
{
	int status;
	StatusText status_text;
	DString data;
	HashMap{String, String} headers;
	ContentType content_type;
}

alias HandlerFn = fn Response(parser::Request, Server *server);

// Entrypoint after user defined handler/middlewares
fn void Server.start(&this, String host = "127.0.0.1", int port = 8080, uint backlog = 10000)
{
	this.host = host;
	this.port = port;
	this.backlog = backlog;

	event_loop::EventLoop? loop_opt = event_loop::create();
	if (catch err = loop_opt)
	{
		io::eprintfn("Failed to create event loop");
		return;
	}
	this.loop = loop_opt;
	defer this.loop.free();

	tcp::TcpConnection*? server_opt = tcp::create(&this.loop);
	if (catch err = server_opt)
	{
		io::eprintfn("Failed to create server");
		return;
	}
	tcp::TcpConnection* server = server_opt;
	defer server.close();

	server.bind(this.host, (ushort)this.port)!!;
	io::printfn("Server listening on http://%s:%d", this.host, this.port);

	server.listen(this.backlog, &on_connection, this)!!;

	this.loop.run()!!;
}

struct ClientCtx
{
	Server* server;
	parser::Parser parser;
}


fn char[] on_alloc(
	tcp::TcpConnection* conn,
	usz suggested_size,
	void* user_data
) => mem::new_array(char, suggested_size);

fn void on_read(tcp::TcpConnection* client, char[] data, void* user_data)
{
	@pool()
	{
		ClientCtx* ctx = (ClientCtx*)user_data;

		if (data.len == 0)
		{
			// EOF - client closed connection
			ctx.parser.free();
			free(ctx);
			client.close();
			return;
		}

		parser::ParseResult? parse_opt = ctx.parser.feed(data);
		if (catch err = parse_opt)
		{
			io::eprintfn("Parse error %s", err);
			ctx.parser.free();
			free(ctx);
			client.close();
			return;
		}

		if (parse_opt == parser::ParseResult.COMPLETE)
		{
			// if(ctx.parser.header.headers.has("expect")){
			// } // Expect: 100-continue

			Server* server = ctx.server;

			TzDateTime ldt = datetime::now().to_local();
			String date = datetime::tformat(DateTimeFormat.RFC3339, ldt);

			Response response = middleware::run_middleware_chain(ctx.parser.request, server);
			defer response.data.free();

			DString content;
			content.tinit();

			content.appendf("HTTP/1.1 %d %s\r\n", response.status, response.status_text);

			// Headers
			content.appendf("Server: CEB/0.1.1\r\n");
			content.appendf("Date: %s\r\n", date);
			content.appendf("Content-Length: %d\r\n", response.data.len());
			content.appendf("Content-Type: %s\r\n", response.content_type.mime_type);

			foreach (key : response.headers.tkeys())
			{
				content.appendf("%s: %s\r\n", key, response.headers.get(key)!!);
			}

			// Data
			content.appendf("\r\n%s", response.data.str_view());

			String content_str = content.str_view();
			client.write((char[])content_str.ptr[:content_str.len], &on_write, ctx)!!;
		}
	};
}

fn void on_write(tcp::TcpConnection* client, int status, void* user_data)
{
	ClientCtx* ctx = (ClientCtx*)user_data;
	if (status != 0)
	{
		io::eprintfn("Write failed");
	}
	ctx.parser.free();
	free(ctx);
	client.close();
}

fn void on_connection(tcp::TcpConnection* server, tcp::TcpConnection* client, void* user_data)
{
	// io::printfn("New client connected!");
	ClientCtx* ctx = mem::new(ClientCtx);
	ctx.server = (Server*)user_data;
	ctx.parser.init();

	client.start_read(&on_alloc, &on_read, ctx)!!;
}

fn Server* Server.init(&self)
{
	self.middleware.init(mem);
	self.router.init();
	return self;
}

fn RouteInfo* Server.find_route(&this, String pathname, HttpVerb method) => this.router.find_route(pathname, method);

fn void* Server.use(&this, Middleware middleware_ctx)
{
	this.middleware.push(middleware_ctx);
	return null;
}
