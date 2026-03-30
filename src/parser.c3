<*
 * HTTP/1.1 Request Parser
 *
 * Incremental state machine parser for HTTP/1.1 requests per RFC 9112.
 * Handles streaming data that arrives in chunks.
 *
 * Body data is stored in a separate binary-safe buffer and accessed
 * on-demand via Request.body() from handlers.
 *>
module ceb::parser;


import std::io;
import std::net::url;
import std::core::string;
import std::collections::map;

import ceb;
import ceb::version;
import ceb::headers;

<* Parser states for incremental parsing *>
enum ParserState : char {
    START,
    REQUEST_LINE,
    HEADERS,
    BODY,
    COMPLETE,
    ERROR,
}

<* Result of parse operation *>
enum ParseResult : char {
    MORE,      // Need more data
    COMPLETE,  // Parsing complete
    ERROR,     // Parse error
}

faultdef PARSE_ERROR, INVALID_REQUEST_LINE, HEADER_TOO_LARGE, REQUEST_TOO_LARGE;
faultdef PROTOCOL_VIOLATION;  // bare LF, null bytes, etc.

// <* HTTP/1.1 request representation *>
struct Request {
    HttpVersion version;
    headers::HeaderMap headers;
    String pathname;
    url::UrlQueryValues query;
    HashMap{String, String} params;
    url::Url url;
    headers::HeaderMap trailers;
    HttpVerb method;
    Parser* _parser;                    // Back-reference for lazy body access
}

<* Get request body data on-demand. Returns raw binary-safe body bytes. *>
fn char[] Request.body(&self) {
    if (!self._parser) {
        return (char[]){};
    }
    return self._parser.get_body();
}

<* Incremental HTTP/1.1 parser *>
struct Parser {
    ParserState state;
    io::ByteBuffer buffer;                  // For request line + headers only
    io::ByteBuffer body_buffer;             // Separate buffer for body data (binary-safe)
    Request request;
    usz bytes_parsed;
    usz max_header_size;
    usz max_request_size;
    usz max_body_size;                      // Separate limit for body data
    usz body_received;                      // Total body bytes accumulated
    bool is_chunked;                        // True if Transfer-Encoding: chunked
    bool headers_complete;                  // True once all headers are parsed
    chunked::ChunkedParser chunked_parser;  // For chunked encoding
}

// Parser configuration defaults
const usz DEFAULT_MAX_HEADER_SIZE = 8 * 1024;        // 8KB
const usz DEFAULT_MAX_REQUEST_SIZE = 1024 * 1024;    // 1MB (headers only)
const usz DEFAULT_MAX_BODY_SIZE = 50 * 1024 * 1024;  // 50MB
const usz DEFAULT_MAX_URI_LENGTH = 8 * 1024;         // 8KB
const usz INITIAL_BUFFER_SIZE = 4 * 1024;            // 4KB

<* Initialize parser with default limits. *>
fn void Parser.init(&self, Allocator allocator = mem) {
    self.state = ParserState.START;
    self.buffer.init(allocator, DEFAULT_MAX_REQUEST_SIZE, INITIAL_BUFFER_SIZE);
    self.body_buffer.init(allocator, DEFAULT_MAX_BODY_SIZE, INITIAL_BUFFER_SIZE);
    self.request.headers.init(allocator);
    self.request.trailers.init(allocator);
    self.request.params.init(allocator);
    self.request._parser = self;
    self.bytes_parsed = 0;
    self.max_header_size = DEFAULT_MAX_HEADER_SIZE;
    self.max_request_size = DEFAULT_MAX_REQUEST_SIZE;
    self.max_body_size = DEFAULT_MAX_BODY_SIZE;
    self.body_received = 0;
    self.is_chunked = false;
    self.headers_complete = false;
    self.chunked_parser.init(&self.request.trailers, allocator);
}

<* Free parser resources. *>
fn void Parser.free(&self) {
    self.buffer.free();
    self.body_buffer.free();
    self.request.headers.free();
    self.request.trailers.free();
    self.request.params.free();
    self.chunked_parser.free();
}

<* Reset parser to initial state for connection reuse. *>
fn void Parser.reset(&self) {
    self.state = ParserState.START;
    self.buffer.read_idx = 0;
    self.buffer.write_idx = 0;
    self.body_buffer.read_idx = 0;
    self.body_buffer.write_idx = 0;
    self.request.headers.clear();
    self.request.trailers.clear();
    self.request.params.clear();
    self.bytes_parsed = 0;
    self.body_received = 0;
    self.is_chunked = false;
    self.headers_complete = false;
    self.chunked_parser.reset();
}

<*
 * Feed data to parser. Returns parse result.
 * Call repeatedly as data arrives from network.
 *
 * After headers are complete, body data is routed to a separate
 * binary-safe buffer with its own size limit.
 *
 * When headers are not yet complete, the incoming data may contain
 * both header and body data (e.g. first read on a large POST).
 * We scan for the end-of-headers marker (\r\n\r\n) to split the
 * data and avoid checking body bytes against header size limits.
 *>
fn ParseResult? Parser.feed(&self, char[] data) {
    if (self.headers_complete) {
        // Body data - route to separate body buffer (no protocol validation)
        if (self.body_received + data.len > self.max_body_size) {
            self.state = ParserState.ERROR;
            return REQUEST_TOO_LARGE~;
        }
        self.body_buffer.write(data)!;
        self.body_received += data.len;
        return self.process()!;
    }

    // Headers not yet complete - incoming data may contain both headers and body.
    // We need to find the \r\n\r\n boundary to avoid checking body bytes
    // against the header size limit.

    // Try to find end-of-headers marker in the incoming data.
    // We also need to account for the marker straddling the boundary between
    // previously buffered data and the new data.
    char[] header_data = data;
    char[] body_data = (char[]){};

    // Search for \r\n\r\n in the combined view (buffered tail + new data)
    // The marker could straddle: up to 3 bytes of it may be in the existing buffer
    usz? split_pos = self.find_header_end(data);

    if (try pos = split_pos) {
        // Found the end-of-headers boundary in the new data at offset `pos`.
        // `pos` points to the first byte AFTER the \r\n\r\n sequence in `data`.
        header_data = data[0 : pos];
        if (pos < data.len) {
            body_data = data[pos ..];
        }
    }

    // Check header portion against size limits
    if (self.bytes_parsed + header_data.len > self.max_request_size) {
        self.state = ParserState.ERROR;
        return HEADER_TOO_LARGE~;
    }

    // Append header portion to header buffer
    if (header_data.len > 0) {
        self.buffer.write(header_data)!;
        self.bytes_parsed += header_data.len;
    }

    // Run state machine to process headers
    ParseResult? result = self.process();
    if (catch err = result) {
        return err~;
    }

    // If headers are now complete and we have leftover body data,
    // route it to the body buffer
    if (self.headers_complete && body_data.len > 0) {
        if (self.body_received + body_data.len > self.max_body_size) {
            self.state = ParserState.ERROR;
            return REQUEST_TOO_LARGE~;
        }
        self.body_buffer.write(body_data)!;
        self.body_received += body_data.len;

        // Continue processing (may complete body parsing)
        return self.process()!;
    }

    return result;
}

<* Get readable buffer data as char array. *>
fn char[] Parser.get_readable_buffer(&self) {
    usz readable = self.buffer.write_idx - self.buffer.read_idx;
    return self.buffer.bytes[self.buffer.read_idx : readable];
}

<*
 * Find the end-of-headers marker (\r\n\r\n) in the new incoming data.
 *
 * Because the marker is 4 bytes, it may straddle the boundary between
 * already-buffered data and the new chunk. We check up to 3 bytes from
 * the tail of the existing buffer combined with the start of `data`.
 *
 * Returns the offset in `data` of the first byte AFTER the \r\n\r\n
 * sequence, or a fault if the marker is not present in `data`.
 *>
fn usz? Parser.find_header_end(&self, char[] data) {
    // Build a small overlap window from the tail of the existing buffer
    // (up to 3 bytes) so we can detect markers that straddle the boundary.
    char[3] tail_buf;
    usz tail_len = 0;
    usz buf_written = self.buffer.write_idx;
    if (buf_written >= 3) {
        tail_len = 3;
    } else {
        tail_len = buf_written;
    }

    if (tail_len > 0) {
        for (usz i = 0; i < tail_len; i++) {
            tail_buf[i] = self.buffer.bytes[buf_written - tail_len + i];
        }
    }

    // Search the combined [tail | data] stream for \r\n\r\n.
    // We use a simple 4-state match: track how many consecutive
    // \r\n chars we've seen so far.
    usz matched = 0;

    // Pre-seed the matcher with the tail bytes
    for (usz i = 0; i < tail_len; i++) {
        char c = tail_buf[i];
        if      (matched == 0 && c == '\r') { matched = 1; }
        else if (matched == 1 && c == '\n') { matched = 2; }
        else if (matched == 2 && c == '\r') { matched = 3; }
        else if (matched == 3 && c == '\n') { matched = 4; }
        else if (c == '\r')                 { matched = 1; }
        else                                { matched = 0; }
    }

    // If already matched inside the tail that means the marker is entirely
    // in the existing buffer - return offset 0 (all of data is body).
    if (matched == 4) {
        return 0;
    }

    // Now scan the new data bytes
    for (usz i = 0; i < data.len; i++) {
        char c = data[i];
        if      (matched == 0 && c == '\r') { matched = 1; }
        else if (matched == 1 && c == '\n') { matched = 2; }
        else if (matched == 2 && c == '\r') { matched = 3; }
        else if (matched == 3 && c == '\n') {
            // Found! Return offset of byte after the \r\n\r\n in `data`
            return i + 1;
        }
        else if (c == '\r')                 { matched = 1; }
        else                                { matched = 0; }
    }

    // Not found in this chunk
    return PARSE_ERROR~;
}

<* Consume N bytes from buffer. *>
fn void Parser.consume_bytes(&self, usz n) {
    self.buffer.read_idx += n;
}

<*
 * Process buffered data through state machine.
 * Returns MORE if needs more data, COMPLETE if done, ERROR on failure.
 *>
fn ParseResult? Parser.process(&self) {
    while (true) {
        switch (self.state) {
            case ParserState.START:
                self.state = ParserState.REQUEST_LINE;

            case ParserState.REQUEST_LINE:
                ParseResult? result = self.parse_request_line();
                if (catch err = result) {
                    self.state = ParserState.ERROR;
                    return err~;
                }
                if (result == ParseResult.MORE) {
                    return ParseResult.MORE;
                }
                self.state = ParserState.HEADERS;

            case ParserState.HEADERS:
                ParseResult? result = self.parse_headers();
                if (catch err = result) {
                    self.state = ParserState.ERROR;
                    return err~;
                }
                if (result == ParseResult.MORE) {
                    return ParseResult.MORE;
                }

                // Headers complete - migrate any leftover buffer data to body buffer
                self.headers_complete = true;
                char[] remaining = self.get_readable_buffer();
                if (remaining.len > 0) {
                    if (remaining.len > self.max_body_size) {
                        self.state = ParserState.ERROR;
                        return REQUEST_TOO_LARGE~;
                    }
                    self.body_buffer.write(remaining)!;
                    self.body_received += remaining.len;
                    self.consume_bytes(remaining.len);
                }
                self.state = ParserState.BODY;

            case ParserState.BODY:
                ParseResult? result = self.parse_body();
                if (catch err = result) {
                    self.state = ParserState.ERROR;
                    return err~;
                }
                if (result == ParseResult.MORE) {
                    return ParseResult.MORE;
                }
                self.state = ParserState.COMPLETE;

            case ParserState.COMPLETE:
                return ParseResult.COMPLETE;

            case ParserState.ERROR:
                return PARSE_ERROR~;
        }
    }
}

<*
 * Parse request line: METHOD TARGET HTTP/VERSION\r\n
 * Returns MORE if incomplete, COMPLETE if done.
 *>
fn ParseResult? Parser.parse_request_line(&self) {
    // Look for CRLF to find end of request line
    String buffer_str = (String)self.get_readable_buffer();
    usz? crlf_pos = find_crlf(buffer_str);

    if (catch err = crlf_pos) {
        // Propagate protocol violations (bare LF, null bytes)
        if (err == PROTOCOL_VIOLATION) {
            return err~;
        }
        // No CRLF yet, check size limit
        if (buffer_str.len > self.max_header_size) {
            return HEADER_TOO_LARGE~;
        }
        return ParseResult.MORE;
    }

    // Extract request line
    String line = buffer_str[0:crlf_pos];

    // Parse: METHOD SP TARGET SP HTTP/VERSION
    String[]? parts = line.tsplit(" ");
    if (catch err = parts) {
        return INVALID_REQUEST_LINE~;
    }

    if (parts.len != 3) {
        return INVALID_REQUEST_LINE~;
    }

    // Parse method
    HttpVerb? parsed_method = utils::string_to_http_verb(parts[0]);
    if (catch err = parsed_method) {
        return INVALID_REQUEST_LINE~;
    }
    self.request.method = parsed_method;

    // Store raw target
    self.request.pathname = parts[1];

    // Validate URI length (414 URI Too Long)
    if (parts[1].len > DEFAULT_MAX_URI_LENGTH) {
        return REQUEST_TOO_LARGE~;
    }

    // Parse target as URL
    // For origin-form (e.g., "/path?query"), prepend scheme+host to make it parseable
    String target_to_parse = parts[1];
    if (target_to_parse.starts_with("/")) {
        // Origin-form: prepend dummy scheme://host for parsing
        target_to_parse = string::tformat("http://localhost%s", target_to_parse);
    }

    // Parse URL (use temp allocator for parsing, will copy what we need)
    url::Url? parsed_url = url::tparse(target_to_parse);
    if (catch err = parsed_url) {
        return INVALID_REQUEST_LINE~;
    }

    // Extract path and query
    self.request.pathname = parsed_url.path.copy(tmem);
    if (parsed_url.query.len > 0) {
        self.request.query = url::parse_query_to_temp(parsed_url.query);
    }

    // For absolute-form, store the full URL
    if (!parts[1].starts_with("/")) {
        self.request.url = parsed_url;
    }

    // Parse version
    HttpVersion? parsed_version = version::parse(parts[2]);
    if (catch err = parsed_version) {
        return INVALID_REQUEST_LINE~;
    }

    // Validate version is supported (HTTP/1.1 only, optionally HTTP/1.0)
    // Return 505 HTTP Version Not Supported for other versions
    if (!parsed_version.is_http11() && !parsed_version.is_http10()) {
        return version::UNSUPPORTED_VERSION~;
    }

    self.request.version = parsed_version;

    // Consume request line + CRLF from buffer
    self.consume_bytes(crlf_pos + 2);

    return ParseResult.COMPLETE;
}

<*
 * Parse headers until empty line (\r\n\r\n).
 * Returns MORE if incomplete, COMPLETE if done.
 *>
fn ParseResult? Parser.parse_headers(&self) {
    while (true) {
        String buffer_str = (String)self.get_readable_buffer();

        // Check size limit
        if (buffer_str.len > self.max_header_size) {
            return HEADER_TOO_LARGE~;
        }

        // Look for CRLF
        usz? crlf_pos = find_crlf(buffer_str);
        if (catch err = crlf_pos) {
        // Propagate protocol violations (bare LF, null bytes)
        if (err == PROTOCOL_VIOLATION) {
            return err~;
        }
            // No CRLF yet
            return ParseResult.MORE;
        }

        // Check for empty line (end of headers)
        if (crlf_pos == 0) {
            // Consume final CRLF
            self.consume_bytes(2);
            return ParseResult.COMPLETE;
        }

        // Parse header line
        String line = buffer_str[0:crlf_pos];
        headers::HeaderField? field = headers::parse_header_line(line);
        if (catch err = field) {
            return PARSE_ERROR~;
        }

        // Add to header map
        self.request.headers.add(field.name, field.value)!;

        // Consume header line + CRLF
        self.consume_bytes(crlf_pos + 2);
    }
}

<*
 * Parse request body based on Content-Length or Transfer-Encoding.
 * Body data lives in body_buffer (binary-safe, no protocol validation).
 * Returns MORE if incomplete, COMPLETE if done.
 *>
fn ParseResult? Parser.parse_body(&self) {
    // Check Transfer-Encoding first (takes precedence over Content-Length)
    if (self.request.headers.is_chunked()) {
        // Mark as chunked on first call to parse_body
        if (!self.is_chunked) {
            self.is_chunked = true;
        }

        // Feed unprocessed body buffer data to chunked parser
        usz available = self.body_buffer.write_idx - self.body_buffer.read_idx;
        if (available > 0) {
            char[] buffer_data = self.body_buffer.bytes[self.body_buffer.read_idx : available];
            bool? complete = self.chunked_parser.feed(buffer_data);
            if (catch err = complete) {
                return PARSE_ERROR~;
            }

            // Mark data as consumed from body buffer
            self.body_buffer.read_idx += available;

            if (complete) {
                return ParseResult.COMPLETE;
            }
        }

        return ParseResult.MORE;
    }

    // Check Content-Length
    usz? content_length = self.request.headers.get_content_length();
    if (catch err = content_length) {
        // No body
        return ParseResult.COMPLETE;
    }

    // Reject body that exceeds size limit (413 Payload Too Large)
    if (content_length > self.max_body_size) {
        return REQUEST_TOO_LARGE~;
    }

    // Check if we have enough data in body buffer
    if (self.body_received < content_length) {
        return ParseResult.MORE;
    }

    // Body is ready
    return ParseResult.COMPLETE;
}

<*
 * Get parsed request. Only valid after parse returns COMPLETE.
 *>
fn Request* Parser.get_request(&self) {
    return &self.request;
}

<* Get request body data. Only valid after parse returns COMPLETE. *>
fn char[] Parser.get_body(&self) {
    // If chunked, return decoded body from chunked parser
    if (self.is_chunked) {
        return self.chunked_parser.get_body();
    }

    // Otherwise, return Content-Length bytes from body buffer
    usz? content_length = self.request.headers.get_content_length();
    if (catch err = content_length) {
        return (char[]){};
    }

    usz available = self.body_buffer.write_idx;
    usz body_len = content_length < available ? content_length : available;
    return self.body_buffer.bytes[0:body_len];
}

<*
 * Find CRLF (\r\n) in string.
 * Returns position of \r, or fault if not found.
 *
 * Rejects bare LF and null bytes per RFC 9112.
 *>
fn usz? find_crlf(String str) {
    // Scan for CRLF and security violations simultaneously
    for (usz i = 0; i < str.len; i++) {
        char c = str[i];

        // SECURITY: Reject null bytes
        if (c == 0) {
            return PROTOCOL_VIOLATION~;
        }

        // SECURITY: Reject bare LF without CR
        if (c == '\n') {
            if (i == 0 || str[i - 1] != '\r') {
                return PROTOCOL_VIOLATION~;
            }
            // This is the '\n' of a proper CRLF, return position of '\r'
            return i - 1;
        }

        // Check if this is '\r' followed by '\n' (proper CRLF)
        if (c == '\r' && i + 1 < str.len && str[i + 1] == '\n') {
            // Found proper CRLF, but continue checking rest of line for null bytes
            // Actually, just return here - we'll check the line on the next call
            return i;
        }
    }

    // Not found yet - need more data
    return PARSE_ERROR~;
}
