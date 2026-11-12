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
    GET  /clock            {"ok": true, "hostMs": <the host's clock>}
    GET  /pipeline         the host's stages the sampler left (pipeline.json)
    GET  /presses?since=N  the presses with an id above N
    POST /presses          {"hostMs": <the host's clock at the press>}
    GET  /flips?since=N    the flips the page saw, with the host's clock
    POST /flips            {"hostMs": <the host's clock at the flip>}
    GET  /player           what the page is doing (playing, closed, …)
    POST /player           {"state": "...", ...}
    POST /stats/stream     one batch of measurements, sent to the host as it is

Of those, exactly two reach the host's automation interface, with the session's
token and no other credentials: `GET /status`, asked for `/clock`, because the
press probe needs the host's own clock; and `POST /stats/stream`, the
measurements the stats framework keeps. Nothing else of the host's API is
reachable through this process — a path it does not list above answers 404,
and its own API (`/players`, `game/start`, `probe/press`, …) has no route here.
A browser on the network can therefore measure a session and nothing more; the
measurements it sends are trusted, because anyone who can open the page can
send them (docs/automation.md).

The body of a POST is one small JSON object: at most `max_body_bytes` (64 KB),
which is a whole batch of a viewer's numbers with room to spare. A longer one
is refused before it is read.
"""

import argparse
import json
import os
import re
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

# The most a POST body may be: one batch of a viewer's measurements is about
# 2 KB and a press is a few dozen bytes, so 64 KB is room and no more. The
# relay is reachable from anywhere the page is, and the host's ingest keeps what
# it is given, so an open body would be an open memory hole. Keep this in step
# with the host's own cap, `maxAutomationBodyBytes` in
# packages/party_host/lib/src/automation/automation_body.dart: a batch the relay
# lets through is one the host must also take.
max_body_bytes = 64 * 1024

# The files the page loads, which are the only things it can fetch from here.
page_files = frozenset(
    (
        "index.html",
        "config.js",
        "player.js",
        "page_state.js",
        "playback.js",
        "streams.js",
        "options.js",
        "latency_probe.js",
        "metrics.js",
        "reporter.js",
        "stats.js",
    )
)

# The folder the page's one library is served from (gstwebrtc-api, written by
# the Dockerfile); a name in it is letters, digits, dots and dashes only.
library_dir = "lib/"

# What a file name may look like: no slashes, no dots leading out of the folder.
plain_name = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*$")


def is_page_file(path):
    """Whether `path` is one of the page's own files, which it may fetch."""
    name = path.lstrip("/")
    # `/` is the page itself: http.server answers it with index.html.
    if name == "" or name in page_files:
        return True
    if name.startswith(library_dir):
        return plain_name.match(name[len(library_dir):]) is not None
    return False


class Relay:
    """What the page and the benchmark send each other, and the host's address."""

    # The only two calls this process makes to the host, with the session's
    # token: its status (for `/clock`) and the measurements (`/stats/stream`).
    # Every other path is answered here or refused, so the relay cannot be
    # turned into a door to the host's own API.
    host_paths = frozenset(("/status", "/stats/stream"))

    def __init__(self, automation_port, token, state_dir):
        self.automation_url = "http://127.0.0.1:%d" % automation_port
        self.token = token
        self.state_dir = state_dir
        self.lock = threading.Lock()
        self.presses = []
        self.flips = []
        self.player = {}

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
    post_paths = frozenset(("/stats/stream", "/presses", "/flips", "/player"))

    def do_GET(self):  # noqa: N802 - the name http.server asks for
        path, _, query = self.path.partition("?")
        if path == "/clock":
            return self._json(200, {"ok": True, "hostMs": self.relay.host_clock_ms()})
        if path == "/pipeline":
            return self._json(200, self.relay.pipeline())
        if path == "/presses":
            return self._json(200, {"ok": True, "presses": self.relay.since(self.relay.presses, _since(query))})
        if path == "/flips":
            return self._json(200, {"ok": True, "flips": self.relay.since(self.relay.flips, _since(query))})
        if path == "/player":
            return self._json(200, {"ok": True, "player": self.relay.player})
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
            status, answer = self.relay.call("POST", "/stats/stream", body)
            return self._json(status, answer)
        if path == "/presses":
            ident = self.relay.add(self.relay.presses, body)
            return self._json(200, {"ok": True, "id": ident})
        if path == "/flips":
            ident = self.relay.add(self.relay.flips, body)
            return self._json(200, {"ok": True, "id": ident})
        # The guard above leaves only `/player` by the time it gets here.
        with self.relay.lock:
            self.relay.player = body
        return self._json(200, {"ok": True})

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
        # Only a refused call is worth a line: the page asks for its presses
        # five times a second, and that would fill the session's log.
        if self.path.startswith("/stats") or self.path.startswith("/clock"):
            sys.stderr.write("relay: %s\n" % (message % args))


def _since(query):
    for part in query.split("&"):
        key, _, value = part.partition("=")
        if key == "since":
            try:
                return int(value)
            except ValueError:
                return 0
    return 0


def _refusal_text(status):
    """The one line the page shows for a body it cannot take."""
    if status == 413:
        return "the body is over %d bytes" % max_body_bytes
    return "the body is a JSON object"


def main():
    parser = argparse.ArgumentParser(description="The Thumb Party player page and its relay (M15 c2).")
    parser.add_argument("--port", type=int, default=8080)
    parser.add_argument("--directory", default="/run/thumb-party/player")
    parser.add_argument("--automation-port", type=int, default=8787)
    parser.add_argument("--token", default="")
    parser.add_argument("--state", default="/run/thumb-party")
    options = parser.parse_args()

    Handler.relay = Relay(options.automation_port, options.token, options.state)
    handler = lambda *args, **kwargs: Handler(*args, directory=options.directory, **kwargs)  # noqa: E731
    server = ThreadingHTTPServer(("0.0.0.0", options.port), handler)
    sys.stderr.write("relay: the player page on %d, the host on %d\n" % (options.port, options.automation_port))
    server.serve_forever()


if __name__ == "__main__":
    main()
