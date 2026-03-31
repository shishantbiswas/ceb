module ceb::utils;

import std::io;
import std::time;

import ceb::enums;
import ceb;

import async::file;

// Handler
fn Response read_file(Server* server, String filename)
{
	DString html_data;
	html_data.init(tmem);

	Response response = { .data = html_data, .status_text = StatusText.OK, .content_type = ContentType.TXT };

	if (!file::is_file(filename))
	{
		// io::eprintfn("[ERROR]: Path '%s' is not a file", filename);
		html_data.append("Internal Server Error");

		response.data = html_data;
		response.status = 500;
		return response;
	}

	char[]? file = file::load(tmem, filename);
	if (catch excuse = file)
	{
		html_data.append("Internal Server Error");

		response.data = html_data;
		response.status = 500;
		return response;
	}

	if (try Path pathname = path::temp(filename))
	{
		if (try String extname = pathname.extension())
		{
			switch (extname)
			{
				case "html":
					response.content_type = ContentType.HTML;
					break;
				case "png":
					response.content_type = ContentType.PNG;
					break;
				case "jpg":
					response.content_type = ContentType.JPEG;
					break;
				case "pdf":
					response.content_type = ContentType.PDF;
					break;
				case "mp4":
					response.content_type = ContentType.MP4;
					break;
				case "js":
					response.content_type = ContentType.JS;
					break;
				case "GIF":
					response.content_type = ContentType.GIF;
					break;
				case "xml":
					response.content_type = ContentType.XML;
					break;
				case "gz":
					response.content_type = ContentType.GZ;
					break;
				case "aac":
					response.content_type = ContentType.AAC;
					break;
				case "mpeg":
					response.content_type = ContentType.MP3;
					break;
				case "css":
					response.content_type = ContentType.CSS;
					break;
				default:
					response.content_type = ContentType.BINARY;
					break;
			}
		}
	}

	html_data.append(file);
	response.status = 200;
	response.data = html_data;
	return response;
}

enum LogPrefix : (String direction)
{
	OUTGOING { "-->" },
	INCOMING { "<--" },
	ERROR    { "xxx" },
}

fn String color_status(int status)
{
	DString color;
	color.init(mem);
	defer color.free();

	switch ((status / 100) | 0)
	{
		case 5: // red = error
			color.append_string("\x1b[31m");
			break;
		case 4: // yellow = warning
			color.append_string("\x1b[33m");
			break;
		case 3: // cyan = redirect
			color.append_string("\x1b[36m");
			break;
		case 2: // green = success
			color.append_string("\x1b[32m");
			break;
		default:
			color.append_string("\x1b[32m");
			break;
	}
	color.appendf("%d", status);
	color.append_string("\x1b[0m");
	return color.str_view();
}

fn void logger_procedure(MiddlewareCtx ctx)
{
	TzDateTime ldt = datetime::now().to_local();
	String date = datetime::tformat(DateTimeFormat.RFC3339, ldt);
	io::printfn(
		"[LOGGER %s]: %s %s at path '%s'",
		date,
		LogPrefix.OUTGOING.direction,
		ctx.request.method.str_val,
		ctx.request.pathname
	);

	ctx.next.call();

	io::printfn(
		"[LOGGER %s]: %s %s at path '%s' %s",
		date,
		LogPrefix.INCOMING.direction,
		ctx.request.method.str_val,
		ctx.request.pathname,
		color_status(ctx.response.status)
	);
}

// pass any config options you need for your custom middlware
fn Middleware logger()
{
	return (Middleware) { .name = "static_serve", .procedure = &logger_procedure, };
}

fn HttpVerb string_to_http_verb(String verb)
{
	switch (verb)
	{
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
		case "OPTIONS":
			return HttpVerb.OPTIONS;
		case "TRACE":
			return HttpVerb.TRACE;
		case "CONNECT":
			return HttpVerb.CONNECT;
		case "HEAD":
			return HttpVerb.HEAD;
		default:
			unreachable("ERROR: Unknown method");
	}
}
