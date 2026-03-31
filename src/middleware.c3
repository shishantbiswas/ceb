module ceb::middleware;

import std::collections::list;

import ceb::enums;
import ceb::parser;

// / Wraps the "advance chain" callback + its context pointer.
// / Call `ctx.next.call()` inside your middleware to proceed to the
// / next middleware (or the final route handler if none remain).
alias FnPtr = fn void(void*);
struct Next
{
	FnPtr fn_ptr;
	void* user_data;
}

fn void Next.call(&self)
{
	if (self.fn_ptr != null)
	{
		self.fn_ptr(self.user_data);
	}
}

// / Context passed to every middleware function.
struct MiddlewareCtx
{
	Next next;
	Request request;
	Response* response;
}

alias MiddlewareFn = fn void(MiddlewareCtx);

// Public interface
struct Middleware
{
	String name;
	MiddlewareFn procedure;
}


// / Run the full middleware chain then call the matching route handler.
// / Returns whichever Response was produced (zero-initialised if none).
fn Response run_middleware_chain(Request request, Server* server)
{
	Middleware[] mw_arr = server.middleware.to_array(tmem);
	MiddlewareRunner runner = {
		.request = request,
		.middleware_ptr = mw_arr.ptr,
		.middleware_count = mw_arr.len,
		.current_index = 0,
		.server = server,
	};
	_middleware_advance(&runner);
	return runner.result;
}


// ---------------------------------------------------------------------------
// Hono-style middleware chain runner
// ---------------------------------------------------------------------------

struct MiddlewareRunner
{
	Request request;
	Middleware* middleware_ptr;
	usz middleware_count;
	usz current_index;
	Server* server;
	Response result;
}


// / Internal libuv-style callback: advances the runner to the next step.
fn void _middleware_advance(void* data)
{
	MiddlewareRunner* runner = (MiddlewareRunner*)data;
	if (runner.current_index < runner.middleware_count)
	{
		usz idx = runner.current_index;
		runner.current_index++;
		MiddlewareCtx ctx = {
			.request = runner.request,
			.response = &runner.result,
			.next = { .fn_ptr = &_middleware_advance, .user_data = runner },
		};
		runner.middleware_ptr[idx].procedure(ctx);
	}
	else
	{
		// All middleware ran — invoke the route handler.
		if (try Response res = runner.server.router.handle_request(runner.request, runner.server))
		{
			runner.result = res;
		}
	}
}
