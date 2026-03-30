module ceb::utils;

import ceb::enums;
import ceb;
import std::io;

fn Response read_file(String filename)
{
	DString html_data;
	html_data.init(tmem);

	Response response = { .data = html_data, .status_text = StatusText.OK,.content_type = ContentType.TXT };

	if (!file::is_file(filename))
	{
		io::eprintfn("[ERROR]: Path '%s' is not a file", filename);
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
