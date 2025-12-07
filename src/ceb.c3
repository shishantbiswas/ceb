module ceb;
import std::collections::list;
import std::net;
import std::net::tcp;
import std::thread;
import std::collections::map;
import std::core::mem::allocator;
import std::core::string;
import std::io::file;

import std::time;
// import std::time::datetime;

import ceb::enums;

struct Server {
  List{Route} routes;
  List{Middleware} middleware;
  TcpServerSocket server;
  String host;
  uint port;
  uint backlog;
}

struct ThreadArgs {
  TcpSocket *socket;
  Server *server;
}

struct Response {
  int status;
  StatusText status_text;
  DString data;
  ContentType content_type;
}

struct Request {
  // int status;
  HashMap{String, String} headers;
  String pathname;
  HttpVerb method;
}

alias HandlerFn = fn Response(Request);

struct Route {
  String path;
  HttpVerb method;
  HandlerFn handler_fn;
  String[] headers;
}

struct MiddlewareCtx {
  String pathname;
  HttpVerb method;
  String[] headers;
  RequestType request_type;
  usz[] body;
}

alias MiddlewareFn = fn void(MiddlewareCtx);

struct Middleware {
  String name;
  MiddlewareFn middleware_fn;
  MiddlewareInvocation invocation;
}

fn void Server.start(
  &this,
  String host = "127.0.0.1",
  int port = 8080,
  uint backlog = 10000
) {
  this.host = host;
  this.port = port;
  this.backlog = backlog;
  TcpServerSocket ? server = tcp::listen(
    this.host,
    this.port,
    this.backlog,
    net::SocketOption.REUSEADDR,
    );

  if (catch err = server) {
    handle_server_error(err);
    return;
  };
  this.server = server;
  io::printf("Server running at port: %d\n", port);
  while (true) {
    TcpSocket ? socket = tcp::accept(&server);
    if (catch err = socket) {
      io::printn("accept error!");
      continue;
    }
    ThreadArgs args = {
        .socket = allocator::clone(&allocator::LIBC_ALLOCATOR, socket),
        .server = this,
    };

    thread::Thread thread;
    thread.create(&process_req,
                  allocator::clone(&allocator::LIBC_ALLOCATOR, args)) !!;
    defer(catch err) { io::printn("error creating thread"); };
    thread.detach() !!;
  }
}

fn Server *Server.get(&this, String path, HandlerFn handler_fn) {
  Route route = {
      .path = path,
      .method = HttpVerb.GET,
      .handler_fn = handler_fn,
  };
  this.routes.push(route);
  return this;
}

fn Server *Server.post(&this, String path, HandlerFn handler_fn) {
  Route route = {
      .path = path,
      .method = HttpVerb.POST,
      .handler_fn = handler_fn,
  };
  this.routes.push(route);
  return this;
}

fn Server *Server.put(&this, String path, HandlerFn handler_fn) {
  Route route = {
      .path = path,
      .method = HttpVerb.PUT,
      .handler_fn = handler_fn,
  };
  this.routes.push(route);
  return this;
}

fn Server *Server.patch(&this, String path, HandlerFn handler_fn) {
  Route route = {
      .path = path,
      .method = HttpVerb.PATCH,
      .handler_fn = handler_fn,
  };
  this.routes.push(route);
  return this;
}

fn Server *Server.delete(&this, String path, HandlerFn handler_fn) {
  Route route = {
      .path = path,
      .method = HttpVerb.DELETE,
      .handler_fn = handler_fn,
  };
  this.routes.push(route);
  return this;
}

fn Route *Server.find_route(&this, String pathname, HttpVerb method) {
    foreach (i, route : this.routes.to_array(&allocator::LIBC_ALLOCATOR)) {
      if (route.path == pathname && route.method == method) {
        return &this.routes[i];
      };
    };
  return null;
}

fn void *Server.use(&this, Middleware middleware_config){
  this.middleware.push(middleware_config);
  return null;
}

alias ListMiddleware = List {Middleware};

fn ListMiddleware Server.find_middleware(
  &this,
  MiddlewareInvocation invocation
){

  ListMiddleware list_middleware;
  list_middleware.init(mem);
    foreach (i, middleware : this.middleware.to_array(&allocator::LIBC_ALLOCATOR)) {
      if (middleware.invocation == MiddlewareInvocation.ALL || middleware.invocation == invocation) {
          list_middleware.push(middleware);
      };
    };
  return list_middleware;
}


// max header size 
const ulong MAX_READ_SIZE = /* 5 MiB */ 1024 * 1024 * 5;

fn int process_req(void *arg) {
@pool_init(&allocator::LIBC_ALLOCATOR, 512){
  ThreadArgs *args = (ThreadArgs *)arg;
  TcpSocket *socket = args.socket;
  Server *server = args.server;

  DString bytes;
  bytes.init(&allocator::LIBC_ALLOCATOR, 256);

  DString data_bytes;
  data_bytes.init(&allocator::LIBC_ALLOCATOR, 256);


  defer {
    socket.close() !!;
    bytes.free();
  };

  char[256] buffer;
  usz data_start = 0;
  bool has_more_data = false;
  int iteration = 0;

  while (try usz bytes_read = socket.read(&buffer)) 
  {
    // io::printf("Iteration: %d\n", iteration++);
    // io::printf("bytes_read: %d\n",  bytes_read);

    String temp_data = (String)buffer[:bytes_read];
    if (try usz header_end = temp_data.index_of("\r\n\r\n")) 
    {
      bytes.append(buffer[:header_end]);
      data_start = header_end + 4;
      // io::printf("data_start: %d bytes_read: %d header_end: %d\n", data_start, bytes_read, header_end);
      // io::printf("data_start == bytes_read: %d\n",data_start == bytes_read);
      // io::printf("bytes_read < 256: %d\n", bytes_read < 256);

      if(data_start == bytes_read && bytes_read < 256) // if no data after header end
      {
        // io::printn("DOES NOT have more data");
        data_bytes.append(buffer[data_start..]);
      } else {
        // io::printn("Should have more data");
        data_bytes.append(buffer[data_start..]);
        has_more_data= true;
      }
      break;
    }
    bytes.append(temp_data);
    if (bytes.len() >= MAX_READ_SIZE) {
      return 1;
    };
    if (bytes_read < 256) {
      break;
    };
  }
  String header_string = bytes.str_view();
  String[] header_list = header_string.split(&allocator::LIBC_ALLOCATOR, "\n", 0, true);

  Request req;
  req.headers.init(&allocator::LIBC_ALLOCATOR);

  foreach (i, header : header_list) {
    if (header.trim().len != 0) {
      if (header.contains(":")) {
        String[] header_key_val = header.split(&allocator::LIBC_ALLOCATOR, ":", 2);
        req.headers.set(header_key_val[0], header_key_val[1]);
      }
    }
  }

  // Header info
  String[] req_info = header_list[0].split(&allocator::LIBC_ALLOCATOR, " ");
  req.method = string_to_http_verb(req_info[0]);
  req.pathname = req_info[1];

  // Start middleware
  MiddlewareCtx ctx = {
    .pathname = req.pathname,
    .method = req.method,
    .headers = header_list,
    .request_type = RequestType.INCOMING,
  };

  ListMiddleware middleware = server.find_middleware(MiddlewareInvocation.BEFORE);
  defer middleware.free();

  foreach (i, mid : middleware) {
    mid.middleware_fn(ctx);
  }

  // Find Route
  Route *route = server.find_route(req.pathname, req.method);
  Response response = {
      .status = 0,
      .status_text = StatusText.CONTINUE,
      .content_type = ContentType.HTML,
  };

  bool expect_100_continue = false;
  foreach (index, header : header_list)
  {
    String[] header_key_val = header.split(&allocator::LIBC_ALLOCATOR, ":", 2);
    if(header_key_val[0] == "Expect")
    {
      expect_100_continue=true;
      break;
    };
  }

  if(has_more_data || expect_100_continue)
  {
    if(expect_100_continue)
    {
      String agree = "HTTP/1.1 100 Continue\r\n\r\n"; 
      usz ? send = socket.write(agree);
      if (catch err = send) {
        io::printn(err);
        return 1;
      }
    }
    while (try usz bytes_read = socket.read(&buffer))
    {
      if(bytes_read == 0)
      {
        break;
      }
      data_bytes.append(buffer[:bytes_read]);
      if(bytes_read < 256)
      {
        break;
      }
    };
  }

  if (route) {
    response = route.handler_fn(req);
  } else {
    // if provided with a not found handler use that
    // if(server.not_found)
    // {

    // }
    DString error;
    error.init(&allocator::LIBC_ALLOCATOR);
    error.append("NOT FOUND 404");

    response = {
        .status = 404,
        .status_text = StatusText.NOT_FOUND,
        .data = error,
        .content_type = ContentType.TXT,
    };
  }

	TzDateTime dt = datetime::now().to_local();

  String date = datetime::format(
    &allocator::LIBC_ALLOCATOR,
    DateTimeFormat.RFC3339,
    dt
  );

  io::printn(date);

  // FIX: add correct time at the time of response for runtime
    String content = string::format(
        &allocator::LIBC_ALLOCATOR,
        "HTTP/1.1 %d %s\r\n"
        "Date: %s\r\n"
        "Server: CEB/0.1.1\r\n"
        "Content-Length: %d\r\n"
        "Content-Type: %s\r\n"
        "%s",
        response.status, response.status_text, date, response.data.len(),
        response.content_type, response.data.str_view(),
    );
    usz ? send = socket.write(content);
    if (catch err = send) {
      io::printn(err);
      return 1;
    }

    ctx.request_type = RequestType.OUTGOING;
    middleware = server.find_middleware(MiddlewareInvocation.AFTER);
    foreach (i, mid : middleware) {
      mid.middleware_fn(ctx);
    }

    return 0;
  
};
}

fn void handle_server_error(fault err) {
  switch (err) {
  case net::INVALID_URL:
    io::printn("ERROR: INVALID_URL");
    return;
  case net::URL_TOO_LONG:
    io::printn("ERROR: URL_TOO_LONG");
    return;
  case net::INVALID_SOCKET:
    io::printn("ERROR: INVALID_SOCKET");
    return;
  case net::GENERAL_ERROR:
    io::printn("ERROR: GENERAL_ERROR");
    return;
  case net::INVALID_IP_STRING:
    io::printn("ERROR: INVALID_IP_STRING");
    return;
  case net::ADDRINFO_FAILED:
    io::printn("ERROR: ADDRINFO_FAILED");
    return;
  case net::CONNECT_FAILED:
    io::printn("ERROR: CONNECT_FAILED");
    return;
  case net::LISTEN_FAILED:
    io::printn("ERROR: LISTEN_FAILED");
    return;
  case net::ACCEPT_FAILED:
    io::printn("ERROR: ACCEPT_FAILED");
    return;
  case net::WRITE_FAILED:
    io::printn("ERROR: WRITE_FAILED");
    return;
  case net::READ_FAILED:
    io::printn("ERROR: READ_FAILED");
    return;
  case net::SOCKOPT_FAILED:
    io::printn("ERROR: SOCKOPT_FAILED");
    return;
  case net::SOCKETS_NOT_INITIALIZED:
    io::printn("ERROR: SOCKETS_NOT_INITIALIZED");
    return;
  case net::STILL_PROCESSING_CALLBACK:
    io::printn("ERROR: STILL_PROCESSING_CALLBACK");
    return;
  case net::BAD_SOCKET_DESCRIPTOR:
    io::printn("ERROR: BAD_SOCKET_DESCRIPTOR");
    return;
  case net::NOT_A_SOCKET:
    io::printn("ERROR: NOT_A_SOCKET");
    return;
  case net::CONNECTION_REFUSED:
    io::printn("ERROR: CONNECTION_REFUSED");
    return;
  case net::CONNECTION_TIMED_OUT:
    io::printn("ERROR: CONNECTION_TIMED_OUT");
    return;
  case net::ADDRESS_IN_USE:
    io::printn("ERROR: ADDRESS_IN_USE");
    return;
  case net::CONNECTION_ALREADY_IN_PROGRESS:
    io::printn("ERROR: CONNECTION_ALREADY_IN_PROGRESS");
    return;
  case net::ALREADY_CONNECTED:
    io::printn("ERROR: ALREADY_CONNECTED");
    return;
  case net::NETWORK_UNREACHABLE:
    io::printn("ERROR: NETWORK_UNREACHABLE");
    return;
  case net::OPERATION_NOT_SUPPORTED_ON_SOCKET:
    io::printn("ERROR: OPERATION_NOT_SUPPORTED_ON_SOCKET");
    return;
  case net::CONNECTION_RESET:
    io::printn("ERROR: CONNECTION_RESET");
    return;
  default:
    io::printn("ERROR: UNKNOWN");
  }
}

fn HttpVerb string_to_http_verb(String verb) {
  switch (verb) {
  case "GET":
    return HttpVerb.GET;
  case "POST":
    return HttpVerb.POST;
  case "PUT":
    return HttpVerb.PUT;
  case "PATCH":
    return HttpVerb.PATCH;
  case "DELETE":
    return HttpVerb.DELETE;
  default:
    unreachable("ERROR: Unknow method");
  }
}