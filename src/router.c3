module ceb::router;

import std::collections::list;
import std::io;

faultdef INVALID_PATH, MULTIPLE_DYNAMIC_PARAMS;

fn bool ? is_dynamic_path(String path, String[] pathlist) {
  if (path.len == 0 && path[0] != '/') {
    return INVALID_PATH ? ;
  }

  // List{String} prefix;
  // prefix.init(tmem);
  // defer prefix.free();

  foreach (sp : pathlist) {
    if (sp.contains(":") && sp.contains("*")) {
      return MULTIPLE_DYNAMIC_PARAMS ? ;
    } // Doesn't support both unlike hono

    usz ? star_index = sp.index_of("*");
    io::printn(sp);
    io::printn(pathlist);
    if (try star_index) {
      io::printn("star_index");
      io::printn(star_index);
      String striped = sp[..(star_index - 1)];
      return path.starts_with(striped);
    } // Early return if *

    String[] path_array = path.tsplit("/"); // ["api", "user", "69"]
    String[] sp_array = sp.tsplit("/");     // ["api", "user", ":id"]

    for (usz i = 0; i < sp_array.len; i++) {
      if (path_array.len == sp_array.len) {
        bool dyn_param = sp_array[i].contains(":");
        if(dyn_param && sp_array.len == i){
          return true;
        }
        if (sp_array[i] != path_array[i]) {
          return false;
        }
      }
    }
  }

  return false;
}