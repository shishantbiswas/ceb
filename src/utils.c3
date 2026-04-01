module ceb::utils;

import std::io;
import std::time;

import ceb::enums;
import ceb;

import async::file;
import uv;

// Handler
struct ReadFileContext
{
	Server* server;
	String filename;
	Context ctx;
	Response response;
    async::file::FileHandle* file;
    usz size;
}


// Handler
fn void read_file(Server* server, String filename, Context ctx)
{
	ReadFileContext* read_ctx = mem::new(ReadFileContext);
	read_ctx.server = server;
	read_ctx.filename = filename;
	read_ctx.ctx = ctx;
	ContentType content_type = ContentType.TXT;
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
		}
	}

	read_ctx.response.data.init(mem);
	read_ctx.response.headers.init(mem);
	read_ctx.response.headers.set("Cache-Control", "max-age=31536000");
    read_ctx.response.status = 200;
    read_ctx.response.status_text = StatusText.OK;
    read_ctx.response.content_type = content_type;

	async::file::stat(&server.loop, filename, &on_read_file_stat, read_ctx);
}

fn void on_read_file_stat(uv::FileStat* stat, int status, void* user_data)
{
	ReadFileContext* ctx = (ReadFileContext*)user_data;
	if (status < 0)
	{
		ctx.response.data.append("Internal Server Error");
		ctx.response.status = 500;
		ctx.ctx.response(ctx.response);
		ctx.ctx.next.call();
		free(ctx);
		return;
	}

    ctx.size = (usz)stat.st_size;
	async::file::open(&ctx.server.loop, ctx.filename, async::file::OPEN_RDONLY, 0, &on_read_file_open, ctx);
}

fn void on_read_file_open(async::file::FileHandle* file, int status, void* user_data)
{
	ReadFileContext* ctx = (ReadFileContext*)user_data;
	if (status < 0 || !file)
	{
		ctx.response.data.append("Internal Server Error");
		ctx.response.status = 500;
		ctx.ctx.response(ctx.response);
		ctx.ctx.next.call();
		free(ctx);
		return;
	}

    ctx.file = file;
	file.read(0, ctx.size, &on_read_file_read, ctx);
}

fn void on_read_file_read(char[] data, int status, void* user_data)
{
	{ReadFileContext* ctx = (ReadFileContext*)user_data;
    bool success = true;
	if (status < 0)
	{
		ctx.response.data.append("Internal Server Error");
		ctx.response.status = 500;
        success = false;
	}
	else
	{
		ctx.response.data.append(data);
		ctx.response.status = 200;
	}

	ctx.ctx.response(ctx.response);
    
    if (ctx.file)
    {
        ctx.file.close(&on_read_file_close, ctx);
    }
    else
    {
        ctx.ctx.next.call();
        free(ctx);
    }}
}

fn void on_read_file_close(int status, void* user_data)
{
    ReadFileContext* ctx = (ReadFileContext*)user_data;
    ctx.ctx.next.call();
    free(ctx);
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
		ctx.req.method.str_val,
		ctx.req.pathname
	);

	ctx.next.call();

	io::printfn(
		"[LOGGER %s]: %s %s at path '%s' %s",
		date,
		LogPrefix.INCOMING.direction,
		ctx.req.method.str_val,
		ctx.req.pathname,
		color_status(ctx._resp_ptr.status)
	);
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
