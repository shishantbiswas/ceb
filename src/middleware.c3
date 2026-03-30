module ceb::middleware;

import std::collections::list;

import ceb::enums;

struct MiddlewareCtx
{
	String pathname;
	HttpVerb method;
	String[] headers;
	RequestType request_type;
	usz[] body;
}

alias MiddlewareFn = fn void(MiddlewareCtx);

struct Middleware
{
	String name;
	MiddlewareFn middleware_fn;
	MiddlewareInvocation invocation;
}

alias ListMiddleware = List{Middleware};

fn ListMiddleware Server.find_middleware(&this, MiddlewareInvocation invocation)
{
	ListMiddleware list_middleware;
	list_middleware.tinit();
	foreach (i, middleware : this.middleware.to_array(tmem))
	{
		if (middleware.invocation == MiddlewareInvocation.ALL || middleware.invocation == invocation)
		{
			list_middleware.push(middleware);
		}
	}
	return list_middleware;
}
