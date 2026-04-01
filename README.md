<div align="left">
  <a href="#">
    <img src="docs/assets/favicon.png" width="150" height="150" alt="Hono"/>
  </a>
</div>


# CEB - C3 Hono-like Backend

A lightweight http server framework written in C3 powered by [c3io](https://github.com/shishantbiswas/c3io) and [libuv](https://github.com/libuv/libuv), inspired by [Hono](https://github.com/honojs/hono), [Elysia](https://elysiajs.com) and [express.js](https://expressjs.com).

## Features

- Simple routing system with HTTP method support 
  - GET
  - PUT
  - POST
  - HEAD
  - TRACE
  - PATCH
  - DELETE
  - CONNECT
- Content type handling (HTML, JSON, TXT, AAC, [etc](/src/enums.c3#ContentType))
- Basic request/response handling
- Static file serving capability

### Low-Level Bindings

- **libuv Bindings** (`uv`) - C3 bindings for libuv API

## Dependencies

- **libuv** - Cross-platform async I/O library
- **C3 compiler** - Version 0.6.x or later

### Installing libuv

**Arch Linux:**
```bash
sudo pacman -S libuv
```

**Ubuntu/Debian:**
```bash
sudo apt install libuv1-dev
```

**macOS:**
```bash
brew install libuv
```

**Fedora:**
```bash
sudo dnf install libuv-devel
```

## Testing

```bash
c3c test
```

The test suite includes 30 tests covering all async modules.

## Usage

### As a Git Submodule

Add ceb as a submodule to your project:

```bash
git submodule add https://github.com/shishantbiswas/ceb.git lib/ceb.c3l
git submodule update --init --recursive

# for updating
# git submodule update --remote --recursive
```

Then add it to your `project.json` file like so:

```json
  // existing config
  
  "dependency-search-paths": [
    "lib"
  ],
  "dependencies": [
    "ceb" // emit the extension
  ]

  // existing config
```

## Minimal Example

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

```bash
c3c build
```

This will create `build/main` in the build directory.
Which is the server executable and can be deployed on most linux system and docker based platforms.

## Project Structure

- `src`     - Source code files detailed below
- `lib`     - Lib files (contains [c3io](https://github.com/shishantbiswas/c3io))
- `test`    - Test files
- `docs`    - Docs for usage of CEB
- `build`   - Compiled output
- `scripts` - Contains useful script to test the server like Apache bench

```txt
src/
├── ceb.c3
├── ceb_handlers.c3     // provider hono like interface like `server.get` and `server.use`
├── chunked.c3          // for chunked data used for streaming
├── enums.c3            // contains enums like (ContentType)
├── examples            // examples directory 
├── headers.c3          // internal parser util for header
├── middleware.c3       // contains middleware code
├── parser.c3           // code for header parser 
├── router.c3           // tree based router similar to linear router from hono
├── utils.c3            // contains utilities, general purpose function
└── version.c3          // http versioning function
```   

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
