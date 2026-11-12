#!/usr/bin/env python3
"""The session's player page and its small relay (M15 c2).

One Python process serves the player page and passes the page's measurements
to the host's automation interface with the session's token, so the browser
needs no token and no cross-origin request. It also carries the two small
pieces the latency probe needs: the host's clock (a ping) and the queue of
presses the benchmark wants timed.

    serve.py --port 45782 --directory /run/thumb-party/player \
        --automation-port 45783 --token <token> --state /run/thumb-party

Every call starts with `/`, and the paths the page (and the benchmark) use are:

    GET  /                 the player page and its files
    GET  /clock            {"ok": true, "hostMs": <the host's clock>}
    GET  /pipeline         the host's stages the sampler left (pipeline.json)
    GET  /presses?since=N  the presses with an id above N
    POST /presses          {"hostMs": <the host's clock at the press>}
    GET  /flips?since=N    the flips the page saw, with the host's clock
    POST /flips            {"hostMs": <the host's clock at the flip>}
    GET  /player           what the page is doing (playing, closed, …)
    POST /player           {"state": "...", ...}
    POST /stats/stream     one batch of measurements, sent to the host as it is

Only the loopback address is used for the automation interface, so a browser
elsewhere can measure a session but never reach the host's own API.
"""

import argparse
import json
import os
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


class Relay:
    """What the page and the benchmark send each other, and the host's address."""

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
        return super().do_GET()

    def do_POST(self):  # noqa: N802 - the name http.server asks for
        path = self.path.partition("?")[0]
        body = self._body()
        if body is None:
            return self._json(400, {"ok": False, "error": "the body is a JSON object"})
        if path == "/stats/stream":
            status, answer = self.relay.call("POST", "/stats/stream", body)
            return self._json(status, answer)
        if path == "/presses":
            ident = self.relay.add(self.relay.presses, body)
            return self._json(200, {"ok": True, "id": ident})
        if path == "/flips":
            ident = self.relay.add(self.relay.flips, body)
            return self._json(200, {"ok": True, "id": ident})
        if path == "/player":
            with self.relay.lock:
                self.relay.player = body
            return self._json(200, {"ok": True})
        return self._json(404, {"ok": False, "error": "no call at %s" % path})

    def _body(self):
        try:
            length = int(self.headers.get("content-length", "0"))
            return json.loads(self.rfile.read(length).decode("utf-8"))
        except (ValueError, OSError):
            return None

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
