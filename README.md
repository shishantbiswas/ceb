# CEB - C3 Hono-like Backend

A lightweight single-threaded http server framework written in C3, inspired by Hono and express.js.

## Features

- Simple routing system with HTTP method support (GET, POST, PUT, PATCH, DELETE)
- Content type handling (HTML, JSON, TXT, AAC)
- Basic request/response handling
- Static file serving capability

## Quick Start

```c3
module main;
import std::io;
import ceb;

fn Response ? homeHandler(Request req) {
    return {
        .data = "Hello World",
        .content_type = ContentType.TXT,
        .status = 200,
    };
}

fn int main() {
    Server server;
    server.routes.init(&allocator::LIBC_ALLOCATOR);

    server.get("/", (HandlerFn)&homeHandler);
    
    io::printf("Server starting...\n");
    server.start(); // defaults to localhost:8080
    
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
- Learning C3 programming
- Experimenting with web server concepts
- Understanding low-level networking
- Educational purposes

Do not use this in production environments.
