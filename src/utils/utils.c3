module ceb::utils;

import std::io;
import std::time;

import ceb::enums;
import ceb;

import async::file;
import uv;
import co;

struct AsyncFileState
{
	co::CoThread* worker_fiber;
	co::CoThread* loop_fiber;
	FileHandle* file;
	int status;
	uv::FileStat* stat;
	DString* data_out;
}

fn void on_open_async(FileHandle* file, int status, void* user_data)
{
	AsyncFileState* state = (AsyncFileState*)user_data;
	state.file = file;
	state.status = status;
	co::co_switch(state.worker_fiber);
}

fn void on_stat_async(uv::FileStat* stat, int status, void* user_data)
{
	AsyncFileState* state = (AsyncFileState*)user_data;
	state.stat = stat;
	state.status = status;
	co::co_switch(state.worker_fiber);
}

fn void on_read_async(char[] data, int status, void* user_data)
{
	AsyncFileState* state = (AsyncFileState*)user_data;
	if (status >= 0 && data.len > 0)
	{
		state.data_out.append(data);
	}
	state.status = status;
	co::co_switch(state.worker_fiber);
}

// Handler
fn Response read_file(Server* server, String filename, Context ctx)
{
	ContentType content_type = ContentType.TXT;
	DString data;
	data.init(mem);
	Response res = {
		.status = 200,
		.status_text = StatusText.OK,
		.content_type = content_type,
		.data = data
	};
	res.headers.tinit();
	res.headers.set("Cache-Control", "max-age=31536000");

	AsyncFileState state = {
		.worker_fiber = co::co_active(),
		.loop_fiber = server.loop_fiber,
		.data_out = &res.data
	};

	if (try Path pathname = path::temp(filename))
	{
		if (try String extname = pathname.extension())
		{
			switch (extname)
			{
				case "html": content_type = ContentType.HTML; break;
				case "png":  content_type = ContentType.PNG;  break;
				case "jpg":  content_type = ContentType.JPEG; break;
				case "pdf":  content_type = ContentType.PDF;  break;
				case "mp4":  content_type = ContentType.MP4;  break;
				case "js":   content_type = ContentType.JS;   break;
				case "gif":  content_type = ContentType.GIF;  break;
				case "svg":  content_type = ContentType.SVG;  break;
				case "xml":  content_type = ContentType.XML;  break;
				case "gz":   content_type = ContentType.GZ;   break;
				case "aac":  content_type = ContentType.AAC;  break;
				case "mpeg": content_type = ContentType.MP3;  break;
				case "css":  content_type = ContentType.CSS;  break;
				default:     content_type = ContentType.BINARY; break;
			}
			res.content_type = content_type;
		}

		// Asynchronous file operations using libuv and libco
		async::file::open(&server.loop, pathname.str_view(), async::file::OPEN_RDONLY, 0, &on_open_async, &state);
		co::co_switch(state.loop_fiber);

		if (state.status >= 0)
		{
			async::file::stat(&server.loop, pathname.str_view(), &on_stat_async, &state);
			co::co_switch(state.loop_fiber);

			if (state.status >= 0)
			{
				state.file.read(0, (usz)state.stat.st_size, &on_read_async, &state);
				co::co_switch(state.loop_fiber);
			}

			state.file.close(null, null);
		}

		if (state.status < 0)
		{
			res.status = 404;
			res.status_text = StatusText.NOT_FOUND;
			res.data.append("File not found or error occurred");
		}
	}
	else
	{
		res.status = 500;
		res.status_text = StatusText.INTERNAL_SERVER_ERROR;
		res.data.append("Invalid path");
	}

	return res;
}

	color.init(mem);
{
	OUTGOING { "-->" },
	INCOMING { "<--" },
	ERROR    { "xxx" },
}

fn String color_status(int status)
{
	DString color;
enum LogPrefix : (String direction)
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

fn Response logger_procedure(Context ctx)
{
	TzDateTime ldt = datetime::now().to_local();
	String date = datetime::tformat(DateTimeFormat.RFC3339, ldt);
	io::printfn(
		"[LOGGER %s]: %s %s at path '%s'",
		date,
		LogPrefix.INCOMING.direction,
		ctx.req.method.str_val,
		ctx.req.pathname
	);

	Response res = ctx.next();

	io::printfn(
		"[LOGGER %s]: %s %s at path '%s' %s",
		date,
		LogPrefix.OUTGOING.direction,
		ctx.req.method.str_val,
		ctx.req.pathname,
		color_status(res.status)
	);
	return res;
}

// pass any config options you need for your custom middlware
fn Middleware logger() => (Middleware) { .name = "LOGGER", .procedure = &logger_procedure };


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