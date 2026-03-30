<div align="left">
  <a href="#">
    <img src="docs/assets/favicon.png" width="150" height="150" alt="Hono"/>
  </a>
</div>

# CEB - C3 Hono-like Backend

A lightweight http server framework written in C3 powered by [c3io](https://github.com/shishantbiswas/c3io) and [libuv](https://github.com/libuv/libuv), inspired by [Hono](https://github.com/honojs/hono) and [express.js]().

## Features

- Simple routing system with HTTP method support 
  - GET
  - POST
  - PUT
  - PATCH
  - DELETE
  - TRACE
  - CONNECT
- Content type handling (HTML, JSON, TXT, AAC)
- Basic request/response handling
- Static file serving capability

## Quick Start

```c3
module main;
import std::io;
import ceb;

fn int main() {
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
  
  io::printf("Server starting...\n");  
  return 0;
}
```

## Building

Make sure you have C3 compiler installed, then:

```sh
c3c build
```

The output binary will be available in the `build` directory.

## Project Structure

- `src` - Source code files
  - `src/main.c3` - Entry point
  - `src/ceb.c3` - Core server implementation
  - `src/enums.c3` - HTTP-related enums and constants
- `build` - Compiled output
- `resources` - Static resources
- `test` - Test files

## Current Limitations

- Early prototype stage
- Not optimized for production use
- Limited error handling
- No security features implemented
- Limited request parsing capabilities
- No SSL/TLS support

## Development Status

This project is in active development and should be considered alpha software. It is primarily intended for:
- Experimenting with web server concepts
- Understanding low-level networking

Do not use this in production environments.
