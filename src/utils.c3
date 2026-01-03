module ceb::utils;

import ceb::enums;
import ceb;
import std::io;

fn Response read_file(String filename) {
  DString html_data;
  html_data.init(mem);
  defer html_data.free();

  char[] ? file = file::load(mem, filename);
  if (catch excuse = file) {
    html_data.append("Internal Server Error");
    return {
        .data = html_data,
        .content_type = ContentType.TXT,
        .status = 500,
        .status_text = StatusText.OK,
    };
  }
  html_data.append(file);
  return {
      .data = html_data,
      .content_type = ContentType.HTML,
      .status = 200,
  };
}



fn HttpVerb string_to_http_verb(String verb) {
  switch (verb) {
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
  default:
    unreachable("ERROR: Unknow method");
  }
}