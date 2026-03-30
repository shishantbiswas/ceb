module ceb::middleware;

import std::collections::list;

import ceb::enums;
import ceb::parser;



// Private, used internally
alias MiddlewareNextFn = fn void();

struct MiddlewareCtx
{
	Request request;
	MiddlewareNextFn next;
}

alias MiddlewareFn = fn void(MiddlewareCtx);



// Public interface
struct Middleware
{
	String name;
	MiddlewareFn procedure;
}

// fn MiddlewareNextFn create_next(int index, Server* server)
// {
// 	Middleware* current_handler = &server.middleware[index];
// 	return fn()=> current_handler.procedure();
// }

// alias ListMiddleware = List{Middleware};

// fn ListMiddleware Server.find_middleware(&this, MiddlewareInvocation invocation)
// {
// 	ListMiddleware list_middleware;
// 	list_middleware.tinit();
// 	foreach (i, middleware : this.middleware.to_array(tmem))
// 	{
// 		if (middleware.invocation == MiddlewareInvocation.ALL || middleware.invocation == invocation)
// 		{
// 			list_middleware.push(middleware);
// 		}
// 	}
// 	return list_middleware;
// }
