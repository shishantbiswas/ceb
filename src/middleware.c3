module ceb::middleware;

import std::collections::list;

import ceb::enums;
import ceb::parser;

/// Wraps the "advance chain" callback + its context pointer.
/// Call `ctx.next.call()` inside your middleware to proceed to the
/// next middleware (or the final route handler if none remain).
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

/// Context passed to every middleware function.
struct MiddlewareCtx
{
	Request request;
	Next    next;
}

alias MiddlewareFn = fn void(MiddlewareCtx);

// Public interface
struct Middleware
{
	String       name;
	MiddlewareFn procedure;
}
