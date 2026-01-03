module ceb::types;


<* HTTP Methods. *>
enum HttpVerb : (int val, String str_val) {
  GET     = {1, "GET"},
  POST    = {2, "POST"},
  PUT     = {3, "PUT"},
  PATCH   = {4, "PATCH "},
  DELETE  = {5, "DELETE" },
  OPTIONS = {6, "OPTIONS"},
  CONNECT = {7, "CONNECT"},
  HEAD    = {8, "HEAD"},
  TRACE   = {9, "TRACE"},
}