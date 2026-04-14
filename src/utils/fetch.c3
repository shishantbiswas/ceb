module utils::fetch;

import std::io;
import std::collections;

import ceb;

import async::tcp;
import co;


struct FetchOpt {
	HttpVerb method;
	HashMap{String, String} headers;
	io::ByteBuffer body;
	bool follow_redirects;
	
}


// fn Response fetch(String url, FetchOpt opt)
// {

// }
