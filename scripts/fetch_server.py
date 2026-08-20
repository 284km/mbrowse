#!/usr/bin/env python3
"""scripts/fetch_server.py — an HTTPS server for the fetch gate, and its certificate.

The gate needs an oracle and a subject fed by the same source. A live URL is neither: the page
changes underneath, so a red run means "the internet moved" as often as it means anything, and a
green one on a machine with no network means nothing at all. So the corpus is served locally, over
real TLS, from a certificate generated here — and `curl` and `mbrowse` are pointed at the same port.

The certificate is generated per run into a temporary directory and is NOT committed. A committed
key would be a key in a public repository whatever it is for, and this one has to name `localhost`
and `127.0.0.1` in its SANs, which is exactly the shape somebody eventually reuses by accident.

Prints one line — `<port> <cadir>` — and then serves until killed.

What the corpus has to contain, and why each one:

  small.html    an ordinary page. The case that passes with almost any implementation.
  nul.bin       a body with zero bytes in it. `mem_to_str` stops at the first one, so this is the
                difference between reading the arena as bytes and reading it as a string.
  big.bin       larger than one `read_chunk`, so a client that reads once and parses gets a prefix.
                On loopback a small body arrives in a single read and hides that entirely.
  chunked.html  `Transfer-Encoding: chunked` with no `Content-Length`, served in several chunks with
                a size line that carries an extension on one of them.
  slow.bin      written in pieces with a pause between them, so the read loop has to come back for
                more even though the total is small. A body that fits in one read cannot tell a
                looping reader from a single-shot one.
  sjis.html     a document that is not ASCII and says so. Every other body here decodes to itself
                whatever the encoding decision was, so without this the sniff-and-decode step is
                reached by the corpus and exercised by none of it.
"""
import http.server, os, socket, ssl, subprocess, sys, tempfile, threading, time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
DATA = os.path.join(ROOT, "test", "data", "fetch")


def make_corpus():
    os.makedirs(DATA, exist_ok=True)
    w = lambda n, b: open(os.path.join(DATA, n), "wb").write(b)
    w("small.html", b"<!DOCTYPE html>\n<html><head><title>small</title></head>\n"
                    b"<body><p>hello</p></body></html>\n")
    # Zero bytes, and one at the very front: a reader that treats the body as a C string returns
    # nothing at all for this, which looks like an empty response rather than a wrong one.
    w("nul.bin", bytes([0]) + bytes(range(256)) * 3 + b"tail\x00\x00end")
    # 200 KB, which is three of the 64 KB reads plus a remainder.
    w("big.bin", bytes((i * 7 + (i >> 8)) & 0xFF for i in range(200 * 1024)))
    w("chunked.html", b"<!DOCTYPE html><html><body>" + b"<p>chunk</p>" * 400 + b"</body></html>")
    w("slow.bin", bytes(range(256)) * 4)
    # Shift_JIS, declared. Everything else here is ASCII, so without this the sniff-and-decode step
    # the pipeline now goes through would be exercised by nothing: every other document decodes to
    # itself whatever the answer was. This one does not — read as windows-1252 it is mojibake, and
    # read as UTF-8 it is invalid.
    sjis = ('<!DOCTYPE html>\n<html><head><meta charset="shift_jis"><title>\u65e5\u672c\u8a9e</title>'
            '</head>\n<body><p>\u3053\u3093\u306b\u3061\u306f\u3001\u4e16\u754c\u3002'
            '\u534a\u89d2\uff76\uff85\u3082\u3042\u308b\u3002</p></body></html>\n')
    w("sjis.html", sjis.encode("shift_jis"))
    # The committed snapshot of a real page, served over real TLS. `pipeline_check.sh` fetches it
    # through `src/main.mere` and requires the picture to equal the one that program draws from the
    # same bytes on disk -- an end-to-end check of the whole pipeline with no oracle, because the two
    # paths are each other's. Read unconditionally rather than behind `if os.path.isfile`: the
    # snapshot is committed, so a missing one is a broken checkout and not a reason to serve less.
    ns = os.path.join(ROOT, "test", "data", "northstar", "example-com", "index.html")
    w("example-com.html", open(ns, "rb").read())


class Handler(http.server.SimpleHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *a):
        pass

    def _body(self, name):
        return open(os.path.join(DATA, name), "rb").read()

    def do_GET(self):
        name = self.path.lstrip("/").split("?")[0]
        path = os.path.join(DATA, name)
        if not name or not os.path.isfile(path):
            self.send_response(404); self.send_header("Content-Length", "0"); self.end_headers()
            return
        body = self._body(name)
        if name == "chunked.html":
            self.send_response(200)
            self.send_header("Content-Type", "text/html")
            self.send_header("Transfer-Encoding", "chunked")
            self.end_headers()
            step = 700
            for i in range(0, len(body), step):
                part = body[i:i + step]
                # One chunk carries an extension, because the size line is allowed one and a parser
                # that reads to the CR rather than stopping at the `;` gets a wrong length.
                ext = b";mbrowse=1" if i == step else b""
                self.wfile.write(b"%x%s\r\n" % (len(part), ext) + part + b"\r\n")
            self.wfile.write(b"0\r\n\r\n")
            self.wfile.flush()
            return
        self.send_response(200)
        self.send_header("Content-Type", "application/octet-stream")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if name == "slow.bin":
            half = len(body) // 2
            self.wfile.write(body[:half]); self.wfile.flush()
            time.sleep(0.4)
            self.wfile.write(body[half:]); self.wfile.flush()
        else:
            self.wfile.write(body)


def main():
    make_corpus()
    d = tempfile.mkdtemp(prefix="mbrowse_fetch_ca.")
    key, crt = os.path.join(d, "key.pem"), os.path.join(d, "cert.pem")
    subprocess.run(
        ["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "1",
         "-keyout", key, "-out", crt, "-subj", "/CN=localhost",
         "-addext", "subjectAltName=DNS:localhost,IP:127.0.0.1"],
        check=True, capture_output=True)

    srv = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    ctx.load_cert_chain(crt, key)
    srv.socket = ctx.wrap_socket(srv.socket, server_side=True)
    port = srv.socket.getsockname()[1]
    # The port and the CA go to stdout before anything is served, because the gate waits on this
    # line rather than on a sleep — a fixed sleep is either a flake or a delay, and usually both.
    print("%d %s" % (port, crt), flush=True)
    srv.serve_forever()


if __name__ == "__main__":
    main()
