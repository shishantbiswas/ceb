module ceb::middleware;

import ceb;

alias MiddlewareFn = fn Response(Context ctx);

// Public interface
struct Middleware
{
	String name;
	MiddlewareFn procedure;
}
