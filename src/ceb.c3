module ceb;
// Std imports
import std::collections::list;
import std::net;
import std::thread;
import std::collections::map;
import std::core::string;
import std::io::file;
import std::time;
import libc;

// Ceb imports
import ceb::enums;
import ceb::router;
import ceb::parser;
import ceb::utils;
import ceb::middleware;

// Async (uv) imports
import async::event_loop;
import async::tcp;

// Coroutine/Fiber (libco) imports
import co;

struct Server
{
	Router router;
	List{Middleware} middleware;
	String host;
	event_loop::EventLoop loop;
	uint port;
	uint backlog;
	co::CoThread* loop_fiber;
}

// Request-local tracking
void* active_ctx;

struct Response
{
	int status;
	StatusText status_text;
	DString data;
	HashMap{String, String} headers;
	ContentType content_type;
}

struct Request {
    HttpVersion version;
    headers::HeaderMap headers;
    String pathname;
    url::UrlQueryValues query;
    HashMap{String, String} params;
    url::Url url;
    headers::HeaderMap trailers;
    HttpVerb method;
    Parser* _parser;
}


struct Context
{
	Request* req;
	Server* server;
	usz _mw_index;
}

fn Response Context.next(&self)
{
	self._mw_index++;
	if (self._mw_index <= self.server.middleware.len())
	{
		Context c = *self;
		return self.server.middleware[self._mw_index - 1].procedure(c);
	}
	else
	{
		Context c = *self;
		return self.server.router.handle_request(self.req, self.server, c);
	}
}

alias HandlerFn = fn Response(Context ctx);


// Server Methods
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

// Entrypoint after user defined handler/middlewares
fn void Server.start(&this, String host = "127.0.0.1", int port = 8080, uint backlog = 10000)
{
	this.host = host;
	this.port = port;
	this.backlog = backlog;
	this.loop_fiber = co::co_active();

	libc::signal(libc::SIGINT, &ctrl_c_handler);

	event_loop::EventLoop? loop_opt = event_loop::create();
	if (catch err = loop_opt)
	{
		io::eprintfn("Failed to create event loop");
		return;
	}
	this.loop = loop_opt;

	tcp::TcpConnection*? server_opt = tcp::create(&this.loop);
	if (catch err = server_opt)
	{
		io::eprintfn("Failed to create server");
		return;
	}
	tcp::TcpConnection* server = server_opt;
	defer server.close();

	server.bind(this.host, (ushort)this.port)!!;

	if(catch err = server.listen(this.backlog, &on_connection, this)){
		io::printf("[ERROR] %s\nFailed to start server\n", err);
		return;
	};

	io::printfn("Server listening on http://%s:%d", this.host, this.port);
	defer this.loop.free();
	this.loop.run()!!;
}

fn void ctrl_c_handler(int sig) {
    io::printf("\nShutting down server...\nExiting gracefully.\n");
    libc::exit(libc::EXIT_SUCCESS);
}

// Request Prossesing
struct ServerConnectionCtx
{
	Server* server;
	parser::Parser parser;
	tcp::TcpConnection* client;
	co::CoThread* fiber;
	bool has_error;
	char[] read_buffer;
	bool write_done;
}

// Async TCP primitives for fibers
fn char[] read_async(tcp::TcpConnection* client, ServerConnectionCtx* ctx)
{
	client.start_read(&on_alloc, &on_read_async, ctx)!!;
	co::co_switch(ctx.server.loop_fiber);
	return ctx.read_buffer;
}

fn void write_async(tcp::TcpConnection* client, char[] data, ServerConnectionCtx* ctx)
{
	ctx.write_done = false;
	client.write(data, &on_write_async, ctx)!!;
	co::co_switch(ctx.server.loop_fiber);
}

fn void on_read_async(tcp::TcpConnection* client, char[] data, void* user_data)
{
	ServerConnectionCtx* ctx = (ServerConnectionCtx*)user_data;
	client.stop_read()!!;
	ctx.read_buffer = data;
	co::co_switch(ctx.fiber);
}

fn void on_write_async(tcp::TcpConnection* client, int status, void* user_data)
{
	ServerConnectionCtx* ctx = (ServerConnectionCtx*)user_data;
	ctx.write_done = true;
	co::co_switch(ctx.fiber);
}


fn char[] on_alloc(
	tcp::TcpConnection* conn,
	usz suggested_size,
	void* user_data
) => mem::new_array(char, suggested_size);

fn void connection_worker(void* data)
{
	@pool()
	{
		ServerConnectionCtx* conn_ctx = (ServerConnectionCtx*)active_ctx;

		while (true)
		{
			char[] read_data = read_async(conn_ctx.client, conn_ctx);
			if (read_data.len == 0) break; // EOF

			parser::ParseResult? parse_opt = conn_ctx.parser.feed(read_data);
			if (catch err = parse_opt)
			{
				io::eprintfn("Parse error: %s", err);
				break;
			}

			if (parse_opt == parser::ParseResult.COMPLETE)
			{
				Context ctx = {
					.req = &conn_ctx.parser.request,
					.server = conn_ctx.server,
					._mw_index = 0
				};

				Response res = ctx.next();
				send_response(res, conn_ctx);
				break; // Currently handle one request per connection for simplicity
			}
		}

		conn_ctx.parser.free();
		conn_ctx.client.close();
		free(conn_ctx);
	};
}

fn void send_response(Response response, ServerConnectionCtx* conn_ctx)
{
	TzDateTime ldt = datetime::now().to_local();
	String date = datetime::tformat(DateTimeFormat.RFC3339, ldt);

	DString content;
	content.tinit();

	content.appendf("HTTP/1.1 %d %s\r\n", response.status, response.status_text.value);
	content.appendf("Server: CEB/0.1.1\r\n");
	content.appendf("Date: %s\r\n", date);
	content.appendf("Content-Length: %d\r\n", response.data.len());
	content.appendf("Content-Type: %s\r\n", response.content_type.mime_type);

	foreach (key : response.headers.tkeys())
	{
		content.appendf("%s: %s\r\n", key, response.headers.get(key)!!);
	}

	content.appendf("\r\n%s", response.data.str_view());

	String content_str = content.str_view();
	write_async(conn_ctx.client, (char[])content_str.ptr[:content_str.len], conn_ctx);

	response.data.free();
}


fn void on_connection(tcp::TcpConnection* server, tcp::TcpConnection* client, void* user_data)
{
	ServerConnectionCtx* ctx = mem::new(ServerConnectionCtx);
	ctx.server = (Server*)user_data;
	ctx.parser.init();
	ctx.client = client;

	// Start connection worker fiber
	ctx.fiber = co::co_create(128 * 1024, &connection_worker);
	active_ctx = ctx;
	co::co_switch(ctx.fiber);
}

