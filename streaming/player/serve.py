#!/usr/bin/env python3
"""The session's player page and its small relay (M15 c2, t1).

One Python process serves the player page and passes the page's measurements
to the host's automation interface with the session's token, so the browser
needs no token and no cross-origin request. It also carries the two small
pieces the latency probe needs: the host's clock (a ping) and the queue of
presses the benchmark wants timed.

    serve.py --port 45782 --directory /run/thumb-party/player \
        --automation-port 45783 --token <token> --state /run/thumb-party

The page talks to this process on these paths, and nothing else answers:

    GET  /                 the player page and the files it loads
    GET  /probe.html       the capability probe, a page of its own (M15 opt1)
    GET  /clock            {"ok": true, "hostMs": <the host's clock>}
    GET  /pipeline         the host's stages the sampler left (pipeline.json)
    GET  /presses?since=N  the presses with an id above N
    POST /presses          {"hostMs": <the host's clock at the press>}
    GET  /flips?since=N    the flips the page saw, with the host's clock
    POST /flips            {"hostMs": <the host's clock at the flip>}
    GET  /player           what the page is doing (playing, closed, …), and the
                           pages of earlier sessions it has been told about
    POST /player           {"state": "...", "sessionId": "...", "pageId": "..."}
    POST /page/error       {"message": "...", "site": "file.js:12"}: one uncaught
                           page error, written to this process's log (M15 opt2b)
    POST /stats/stream     one batch of measurements, sent to the host as it is
    GET  /tap              a WebSocket upgrade, passed to the tap server (opt2-2)

Every report and batch names the session its page loaded (`config.js` gives it
to the page), and one from an earlier session is not this session's (M15 fix8):
its report is answered `stale` and named in `GET /player`, it never becomes this
page's state, and its measurements are refused rather than counted.

Of those, exactly two reach the host's automation interface, with the session's
token and no other credentials: `GET /status`, asked for `/clock`, because the
press probe needs the host's own clock; and `POST /stats/stream`. Nothing else
of the host's API is reachable here — a path it does not list above answers 404
— so a browser on the network can measure a session and nothing more; what it
sends is trusted, because anyone who can open the page can send it
(docs/automation.md).

The tap rides on this port too (PROTOCOL.md): a GET for exactly `/tap` that asks
for `Upgrade: websocket` is passed, byte for byte both ways, to the session's tap
server on loopback at `--tap-port` — and nothing else ever is.

The body of a POST is one small JSON object, at most `max_body_bytes` (64 KB).
"""

import argparse
import json
import os
import re
import socket
import sys
import threading
import urllib.error
import urllib.request
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

# The most presses or flips one session keeps: a benchmark sends a few dozen.
max_events = 1000

# The seconds a call to the host may take before it is given up.
host_timeout_s = 5

# The path every automation call starts with.
automation_prefix = "/automation/v1"

# The most pages of earlier sessions one relay remembers: a run leaves one or
# two, and `GET /player` carries the list (M15 fix8).
max_stale_pages = 10

# The most of a page error's text one log line carries (M15 opt2b).
max_error_chars = 200

# The most a POST body may be: a batch of measurements is about 2 KB, so 64 KB
# is room and no more — the relay is reachable from anywhere the page is, and an
# open body would be an open memory hole. Keep it in step with the host's own
# cap, `maxAutomationBodyBytes` in
# packages/party_host/lib/src/automation/automation_body.dart.
max_body_bytes = 64 * 1024

# Where the tap server listens, the most of a tunnelled stream one read holds, and its wait.
tap_address = "127.0.0.1"
tunnel_read_bytes = 64 * 1024
tunnel_connect_timeout_s = 2

# The files the page loads, which are the only things it can fetch from here.
page_files = frozenset(
    (
        "index.html", "config.js", "player.js", "page_state.js", "playback.js",
        "streams.js", "options.js", "jb_target.js", "low_delay.js", "latency_probe.js",
        "marker_batch.js", "marker_decode.js", "marker_reader.js", "clock_sync.js",
        "metrics.js", "reporter.js", "session_end.js", "overlay.js", "stats.js",
        # The page's error trap (M15 opt2b), the capability probe (M15 opt1,
        # a page of its own), and the custom player's files (M15 opt2).
        "error_trap.js", "probe.html", "wc_annexb.js", "wc_counters.js", "wc_decoder.js", "wc_player.js",
        "wc_sound.js", "wc_stats.js",
    )
)

# The folder the page's one library is served from (gstwebrtc-api, by the Dockerfile).
library_dir = "lib/"

# What a file name may look like: no slashes, no dots leading out of the folder.
plain_name = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*$")


def is_page_file(path):
    """Whether `path` is one of the page's own files, which it may fetch; `/` is the page."""
    name = path.lstrip("/")
    if name == "" or name in page_files:
        return True
    return name.startswith(library_dir) and plain_name.match(name[len(library_dir):]) is not None


class Relay:
    """What the page and the benchmark send each other, and the host's address."""

    # The only two calls this process makes to the host, with the session's token:
    # its status (for `/clock`) and the measurements (`/stats/stream`). Every other
    # path is answered here or refused, so this is no door to the host's own API.
    host_paths = frozenset(("/status", "/stats/stream"))

    def __init__(self, automation_port, token, state_dir, session_id=""):
        self.automation_url = "http://127.0.0.1:%d" % automation_port
        self.token = token
        self.state_dir = state_dir
        # The session this relay serves, as its `config.js` gives it (M15 fix8).
        self.session_id = session_id
        self.lock = threading.Lock()
        self.presses = []
        self.flips = []
        self.player = {}
        # The pages of earlier sessions the relay was told about, newest last (M15 fix8).
        self.stale_pages = []

    def claims_this_session(self, claimed):
        """Whether a page that names session [claimed] was served by this one.

        A page left open from an earlier session names that session; a page that names
        none was served before sessions named one, and is this one's own.
        """
        if self.session_id == "" or claimed == "":
            return True
        return isinstance(claimed, str) and claimed == self.session_id

    def note_stale_page(self, page_id):
        """Keeps a page of an earlier session, once, for the bench to name."""
        if not isinstance(page_id, str) or page_id == "" or page_id in self.stale_pages:
            return
        self.stale_pages.append(page_id)
        del self.stale_pages[:-max_stale_pages]

    def add(self, events, body):
        with self.lock:
            ident = (events[-1]["id"] + 1) if events else 0
            events.append({"id": ident, "hostMs": body.get("hostMs")})
            del events[:-max_events]
            return ident

    def since(self, events, after):
        with self.lock:
            return [event for event in events if event["id"] > after]

    def call(self, method, path, body=None):
        """One automation call, answering (status, decoded body or text)."""
        if path not in self.host_paths:
            return 404, {"ok": False, "error": "the relay makes no call at %s" % path}
        data = None if body is None else json.dumps(body).encode("utf-8")
        request = urllib.request.Request(self.automation_url + automation_prefix + path, data=data, method=method)
        request.add_header("x-automation-token", self.token)
        if data is not None:
            request.add_header("content-type", "application/json")
        try:
            with urllib.request.urlopen(request, timeout=host_timeout_s) as answer:
                return answer.status, json.loads(answer.read().decode("utf-8"))
        except urllib.error.HTTPError as error:
            try:
                return error.code, json.loads(error.read().decode("utf-8"))
            except ValueError:
                return error.code, {"ok": False, "error": "the host refused the call"}
        except (urllib.error.URLError, OSError) as error:
            return 502, {"ok": False, "error": "the host is not answering: %s" % error}

    def host_clock_ms(self):
        status, body = self.call("GET", "/status")
        if status != 200 or not isinstance(body, dict):
            return None
        return body.get("hostMs")

    def note_page_error(self, body):
        """Writes one page error to this process's log, where a run reads it (M15 opt2b)."""
        fields = (str(body.get(key) or "")[:max_error_chars] for key in ("sessionId", "site", "message"))
        sys.stderr.write("relay: page error: %s\n" % " ".join(fields))

    def pipeline(self):
        try:
            with open(os.path.join(self.state_dir, "pipeline.json"), encoding="utf-8") as handle:
                return json.load(handle)
        except (OSError, ValueError):
            return {}


class Handler(SimpleHTTPRequestHandler):
    """The page, the relay's calls and the files beside the page."""

    relay = None

    # The paths a POST may go to; anything else is refused before its body is
    # read, so an unlisted path never gets as far as the host.
    post_paths = frozenset(("/stats/stream", "/presses", "/flips", "/player", "/page/error"))

    # The tap server's port from `--tap-port`; 0 (its default, off) is no /tap path.
    tap_port = 0

    def do_GET(self):  # noqa: N802 - the name http.server asks for
        path, _, query = self.path.partition("?")
        if path == "/tap" and self.tap_port:
            if "websocket" not in self.headers.get("upgrade", "").lower():
                return self._json(400, {"ok": False, "error": "/tap is a WebSocket upgrade"})
            return self._tunnel()
        if path == "/clock":
            return self._json(200, {"ok": True, "hostMs": self.relay.host_clock_ms()})
        if path == "/pipeline":
            return self._json(200, self.relay.pipeline())
        if path in ("/presses", "/flips"):
            events = self.relay.presses if path == "/presses" else self.relay.flips
            return self._json(200, {"ok": True, path[1:]: self.relay.since(events, _since(query))})
        if path == "/player":
            return self._json(
                200,
                {"ok": True, "player": self.relay.player, "stalePages": list(self.relay.stale_pages)},
            )
        if is_page_file(path):
            return super().do_GET()
        return self._json(404, {"ok": False, "error": "no file at %s" % path})

    def do_POST(self):  # noqa: N802 - the name http.server asks for
        path = self.path.partition("?")[0]
        if path not in self.post_paths:
            return self._json(404, {"ok": False, "error": "no call at %s" % path})
        body, refused = self._body()
        if refused is not None:
            return self._json(refused, {"ok": False, "error": _refusal_text(refused)})
        if not isinstance(body, dict):
            return self._json(400, {"ok": False, "error": _refusal_text(400)})
        if path == "/stats/stream":
            # An earlier session's page is not a viewer of this one, so its
            # numbers never reach the host (M15 fix8).
            if not self.relay.claims_this_session(self.headers.get("x-player-session", "")):
                return self._json(403, {"ok": False, "error": "this page belongs to an earlier session"})
            status, answer = self.relay.call("POST", "/stats/stream", body)
            return self._json(status, answer)
        if path in ("/presses", "/flips"):
            events = self.relay.presses if path == "/presses" else self.relay.flips
            return self._json(200, {"ok": True, "id": self.relay.add(events, body)})
        if path == "/page/error":
            # A page's own failure is one log line, never this session's state.
            self.relay.note_page_error(body)
            return self._json(200, {"ok": True})
        # The guard above leaves only `/player` by the time it gets here.
        return self._player(body)

    def _player(self, body):
        """Records what this session's page is doing, and names the others."""
        if self.relay.claims_this_session(body.get("sessionId", "")):
            with self.relay.lock:
                self.relay.player = body
            return self._json(200, {"ok": True})
        with self.relay.lock:
            self.relay.note_stale_page(body.get("pageId"))
        return self._json(200, {"ok": True, "stale": True})

    def _tunnel(self):
        """Passes this connection to the tap server, byte for byte both ways (PROTOCOL.md).

        The relay never looks into a frame and holds one read of it at most.
        """
        try:
            tap = socket.create_connection((tap_address, self.tap_port), timeout=tunnel_connect_timeout_s)
        except OSError as error:
            return self._json(502, {"ok": False, "error": "the tap server is not answering: %s" % error})
        tap.settimeout(None)
        for sock in (tap, self.connection):
            sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        # The head as the page sent it: the tap server does the handshake.
        head = self.requestline + "\r\n" + "".join("%s: %s\r\n" % item for item in self.headers.items()) + "\r\n"
        self.close_connection = True
        threading.Thread(target=_copy, args=(tap.recv, self.connection.sendall), daemon=True).start()
        try:
            tap.sendall(head.encode("latin-1"))
            _copy(self.rfile.read1, tap.sendall)
        finally:
            _shut(tap)
            _shut(self.connection)

    def _body(self):
        """The POST's JSON object, or (None, the status to refuse it with)."""
        try:
            length = int(self.headers.get("content-length", "0"))
        except ValueError:
            return None, 400
        if length > max_body_bytes:
            return None, 413
        try:
            return json.loads(self.rfile.read(length).decode("utf-8")), None
        except (ValueError, OSError):
            return None, 400

    def _json(self, status, body):
        text = json.dumps(body).encode("utf-8")
        self.send_response(status)
        self.send_header("content-type", "application/json")
        self.send_header("content-length", str(len(text)))
        self.end_headers()
        self.wfile.write(text)

    def log_message(self, message, *args):
        # Only a measurement or a clock ping is worth a line; the page's press
        # polls five times a second would fill the session's log.
        if self.path.startswith("/stats") or self.path.startswith("/clock"):
            sys.stderr.write("relay: %s\n" % (message % args))


def _copy(read, write):
    """Copies one side of a tunnel to the other until a side closes."""
    try:
        while True:
            data = read(tunnel_read_bytes)
            if not data:
                return
            write(data)
    except OSError:
        pass  # a socket closed under the copy, which is how a tunnel ends


def _shut(sock):
    """Ends a tunnel socket both ways, so a thread blocked on it returns."""
    try:
        sock.shutdown(socket.SHUT_RDWR)
    except OSError:
        pass


def _since(query):
    for part in query.split("&"):
        key, _, value = part.partition("=")
        if key == "since" and value.isdigit():
            return int(value)
    return 0


def _refusal_text(status):
    """The one line the page shows for a body it cannot take."""
    return "the body is over %d bytes" % max_body_bytes if status == 413 else "the body is a JSON object"


def main():
    parser = argparse.ArgumentParser(description="The Thumb Party player page and its relay (M15 c2).")
    parser.add_argument("--port", type=int, default=8080)
    parser.add_argument("--directory", default="/run/thumb-party/player")
    parser.add_argument("--automation-port", type=int, default=8787)
    parser.add_argument("--token", default="")
    parser.add_argument("--state", default="/run/thumb-party")
    parser.add_argument("--session-id", default="")
    parser.add_argument("--tap-port", type=int, default=0)
    options = parser.parse_args()

    Handler.relay = Relay(options.automation_port, options.token, options.state, options.session_id)
    Handler.tap_port = options.tap_port
    handler = lambda *args, **kwargs: Handler(*args, directory=options.directory, **kwargs)  # noqa: E731
    server = ThreadingHTTPServer(("0.0.0.0", options.port), handler)
    sys.stderr.write("relay: the player page on %d, the host on %d\n" % (options.port, options.automation_port))
    server.serve_forever()


if __name__ == "__main__":
    main()
