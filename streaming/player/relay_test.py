#!/usr/bin/env python3
"""The player relay's own test (M15 g1), run inside the distro by `tools/stream.sh
selftest`.

The relay is the session's one door to the host's API, so what it answers, what
it refuses and the size it refuses without reading are worth a test of their
own, beside the code they check. It starts `serve.py` on free loopback ports
with no host behind it (the automation port answers nothing), asks it the
page's calls, and exits 1 at the first thing that does not hold.

    python3 streaming/player/relay_test.py
"""

import http.client
import json
import os
import socket
import subprocess
import sys
import tempfile
import time

# The relay's own cap: a body at this size is refused before it is read.
max_body_bytes = 64 * 1024

# How long the relay gets to answer its first request.
start_timeout_s = 10

# The most a call may take: the relay is on this machine.
answer_timeout_s = 10

passed = 0


def check(condition, what):
    """One assertion, with the line the report quotes when it fails."""
    global passed
    if not condition:
        sys.stderr.write("relay test: FAILED: %s\n" % what)
        sys.exit(1)
    passed += 1
    print("ok %d: %s" % (passed, what))


def free_port():
    """A port nothing listens on: bound, read, and given back."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as probe:
        probe.bind(("127.0.0.1", 0))
        return probe.getsockname()[1]


def call(port, method, path, body=None, headers=None):
    """One HTTP call to the relay, answering (status, decoded body or text)."""
    connection = http.client.HTTPConnection("127.0.0.1", port, timeout=answer_timeout_s)
    try:
        payload = None if body is None else json.dumps(body).encode("utf-8")
        sent = dict(headers or {})
        if payload is not None:
            sent["content-type"] = "application/json"
        connection.request(method, path, body=payload, headers=sent)
        answer = connection.getresponse()
        text = answer.read().decode("utf-8")
        try:
            return answer.status, json.loads(text)
        except ValueError:
            return answer.status, text
    finally:
        connection.close()


def promised_body(port, path, length):
    """A POST to [path] whose body of [length] bytes is promised and never sent.

    Answers (head, body) of the reply. Nothing more is sent, so the relay has to
    answer from the header alone — if it waits for the body, this read waits for
    its timeout instead. The relay closes after the answer, so reading to the
    end is the whole reply.
    """
    with socket.create_connection(("127.0.0.1", port), timeout=answer_timeout_s) as raw:
        raw.sendall(
            (
                "POST %s HTTP/1.1\r\nHost: 127.0.0.1\r\n"
                "Content-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % (path, length)
            ).encode("ascii")
        )
        chunks = []
        while True:
            chunk = raw.recv(4096)
            if not chunk:
                break
            chunks.append(chunk)
    answer = b"".join(chunks).decode("utf-8", "replace")
    head, _, body = answer.partition("\r\n\r\n")
    return head, body


def wait_until_listening(port):
    """Waits for the relay to answer `/player`, up to [start_timeout_s]."""
    deadline = time.monotonic() + start_timeout_s
    while time.monotonic() < deadline:
        try:
            status, _ = call(port, "GET", "/player")
            if status == 200:
                return
        except OSError:
            pass
        time.sleep(0.1)
    raise SystemExit("relay test: the relay did not answer within %ds" % start_timeout_s)


def test_page(port):
    status, _ = call(port, "GET", "/")
    check(status == 200, "the page itself is served at /")
    served = [
        call(port, "GET", name)[0]
        for name in (
            "/player.js",
            "/options.js",
            "/low_delay.js",
            "/metrics.js",
            "/playback.js",
            "/streams.js",
            "/page_state.js",
            "/latency_probe.js",
            "/clock_sync.js",
            "/marker_batch.js",
            "/marker_decode.js",
            "/marker_reader.js",
            "/session_end.js",
            "/overlay.js",
        )
    ]
    check(served == [200] * len(served), "the page's own files are served")


def test_probe_page(port):
    """The capability probe (M15 opt1 o1-3) rides on the same server, alone.

    It is a page of its own, so the player page's files are beside it and
    unchanged; a file in the same folder that is not the page's is still 404.
    """
    status, body = call(port, "GET", "/probe.html")
    check(status == 200, "the capability probe is served at /probe.html")
    check(isinstance(body, str) and "Copy report" in body, "and is the probe page, not a file it found")
    status, body = call(port, "GET", "/serve.py")
    check(status == 404, "a file beside the page that the page does not load is still 404")


def test_unlisted_paths(port):
    status, body = call(port, "GET", "/automation/v1/status")
    check(status == 404, "a GET outside the page's calls is 404")
    check("no file at /automation/v1/status" in body.get("error", ""), "and says which path it does not serve")

    status, body = call(port, "POST", "/players", {})
    check(status == 404, "a POST outside the four the page makes is 404")
    check("no call at /players" in body.get("error", ""), "and is refused before its body is read")

    # The proof of "before its body": a body promised and never sent still gets
    # the answer, so the relay did not wait for it.
    head, _ = promised_body(port, "/players", max_body_bytes)
    check(" 404 " in head, "an unlisted POST with a body promised and not sent is answered at once")


def test_measurements(port):
    status, body = call(port, "POST", "/stats/stream", {"stages": [], "gauges": []})
    check(status == 502, "a measurement with no host behind the relay is a 502")
    check("the host is not answering" in body.get("error", ""), "and says the host is not answering")


def test_page_calls(port):
    status, body = call(port, "POST", "/player", {"state": "playing"})
    check(status == 200, "the page reports what it is doing")

    status, body = call(port, "POST", "/presses", {"hostMs": 1000})
    first = body.get("id")
    check(status == 200 and first == 0, "a press is queued under its own id")

    status, body = call(port, "POST", "/presses", {"hostMs": 1040})
    check(body.get("id") == 1, "the next press gets the next id")

    status, body = call(port, "GET", "/presses?since=%d" % first)
    check([press["hostMs"] for press in body.get("presses", [])] == [1040], "and is read back after the id given")

    status, body = call(port, "GET", "/clock")
    check(status == 200 and body.get("hostMs") is None, "the clock is null while no host answers, not an error")


def test_oversized_body(port):
    head, body = promised_body(port, "/stats/stream", max_body_bytes + 1)
    check(" 413 " in head, "a body over 64 KB is refused with 413")
    check("over %d bytes" % max_body_bytes in body, "and the answer says the size")


def test_session_identity(port):
    """A page an earlier session served is told apart from this one's (M15 fix8).

    This relay runs as the session `test-session`. A page answers the session it
    first joined, so a page still open from an earlier one names that: its report
    is not this session's state, it is named in the relay's answer for the bench
    to say so, and the measurements it sends are refused rather than counted.
    """
    status, body = call(port, "POST", "/player", {"state": "playing"})
    check(status == 200 and body.get("stale") is not True, "a page that names no session is this session's")

    status, body = call(port, "POST", "/player", {"state": "streaming", "sessionId": "earlier", "pageId": "p1"})
    check(status == 200 and body.get("stale") is True, "a page from an earlier session is answered stale")

    status, body = call(port, "GET", "/player")
    check(body.get("player", {}).get("state") == "playing", "and what it says is not this session's page")
    check(body.get("stalePages") == ["p1"], "the ignored page is named in the relay's answer")

    call(port, "POST", "/player", {"state": "playing", "sessionId": "earlier", "pageId": "p1"})
    status, body = call(port, "GET", "/player")
    check(body.get("stalePages") == ["p1"], "the same page is named once")

    status, body = call(
        port, "POST", "/stats/stream", {"stages": [], "gauges": []}, {"x-player-session": "earlier"}
    )
    check(status == 403, "an earlier session's batch is refused")
    check("earlier session" in body.get("error", ""), "and says the page belongs to an earlier session")

    status, body = call(
        port, "POST", "/stats/stream", {"stages": [], "gauges": []}, {"x-player-session": "test-session"}
    )
    check(status == 502, "this session's batch goes on to the host")


def main():
    player_dir = os.path.dirname(os.path.abspath(__file__))
    port = free_port()
    host_port = free_port()
    with tempfile.TemporaryDirectory(prefix="relay-test-") as state:
        server = subprocess.Popen(
            [
                sys.executable or "python3",
                os.path.join(player_dir, "serve.py"),
                "--port",
                str(port),
                "--directory",
                player_dir,
                "--automation-port",
                str(host_port),
                "--state",
                state,
                # The relay's own session, so a page's claim can be told apart
                # from it (M15 fix8).
                "--session-id",
                "test-session",
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        try:
            wait_until_listening(port)
            test_page(port)
            test_probe_page(port)
            test_unlisted_paths(port)
            test_measurements(port)
            test_page_calls(port)
            test_oversized_body(port)
            test_session_identity(port)
        finally:
            server.terminate()
            server.wait(timeout=answer_timeout_s)
    print("relay test: %d checks passed" % passed)


if __name__ == "__main__":
    main()
