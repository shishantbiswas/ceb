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
	Request* req;
	Server* server;
	Response* _resp_ptr;
	Next next;
}

fn void MiddlewareCtx.response(&self, Response res)
{
	*self._resp_ptr = res;
}

alias MiddlewareFn = fn void(MiddlewareCtx);

// Public interface
struct Middleware
{
	String name;
	MiddlewareFn procedure;
}


alias ChainCompleteCallback = fn void(Response response, void* user_data);

// / Run the full middleware chain then call the matching route handler.
// / Returns whichever Response was produced (zero-initialised if none).
fn void run_middleware_chain(Request* request, Server* server, void* user_data, ChainCompleteCallback complete_cb)
{
	Middleware[] mw_arr = server.middleware.to_array(tmem);
	MiddlewareRunner* runner = mem::new(MiddlewareRunner);
	*runner = {
		.request = request,
		.middleware_ptr = mw_arr.ptr,
		.middleware_count = mw_arr.len,
		.current_index = 0,
		.server = server,
		.user_data = user_data,
		.complete_cb = complete_cb,
	};
	runner.result.headers.tinit();
	_middleware_advance(runner);
}


// ---------------------------------------------------------------------------
// Hono-style middleware chain runner
// ---------------------------------------------------------------------------

struct MiddlewareRunner
{
	Request* request;
	Middleware* middleware_ptr;
	usz middleware_count;
	usz current_index;
	Server* server;
	Response result;
	void* user_data;
	ChainCompleteCallback complete_cb;
}


// / Internal libuv-style callback: advances the runner to the next step.
fn void _middleware_advance(void* data)
{
	MiddlewareRunner* runner = (MiddlewareRunner*)data;
	if (runner.current_index < runner.middleware_count)
	{
		usz idx = runner.current_index;
		runner.current_index++;
		MiddlewareCtx m_ctx = {
			.req = runner.request,
			.server = runner.server,
			._resp_ptr = &runner.result,
			.next = { .fn_ptr = &_middleware_advance, .user_data = runner },
		};
		runner.middleware_ptr[idx].procedure(m_ctx);
	}
	else
	{
		// All middleware ran — invoke the route handler.
		runner.server.router.handle_request(runner.request, runner.server, {
			.req = runner.request,
			.server = runner.server,
			._resp_ptr = &runner.result,
			.next = { .fn_ptr = &_middleware_finish, .user_data = runner }
		});
	}
}

fn void _middleware_finish(void* data)
{
	MiddlewareRunner* runner = (MiddlewareRunner*)data;
	if (runner.complete_cb)
	{
		runner.complete_cb(runner.result, runner.user_data);
	}
	free(runner);
}
