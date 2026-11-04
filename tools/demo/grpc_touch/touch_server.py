"""Long-running touch helper for the demo video's touch driver (runbook 2.4).

Talks to the emulator's gRPC control port, which takes touches in *display*
pixels, so there is no raw-axis or rotation arithmetic to get wrong.

It reads one JSON command per line on stdin and writes one JSON reply per line
on stdout, so the Dart touch driver can keep it running for a whole take:

    {"cmd":"ping"}
    {"cmd":"tap","x":2000,"y":73,"ms":80}
    {"cmd":"down","id":0,"x":266,"y":520}
    {"cmd":"move","id":0,"x":300,"y":560}
    {"cmd":"up","id":0}
    {"cmd":"selftest"}

Start it with the emulator's gRPC endpoint and token:

    python touch_server.py --endpoint 127.0.0.1:8554 --token-file <path>

The emulator must have been started with `-grpc 8554 -grpc-use-token`.
"""

import argparse
import json
import subprocess
import sys
import time

import grpc

import emulator_controller_pb2 as pb
import emulator_controller_pb2_grpc as pbg

ADB = r"C:\Users\singh\AppData\Local\Android\Sdk\platform-tools\adb.exe"


class EmuTouch:
    def __init__(self, endpoint, token):
        self.channel = grpc.insecure_channel(endpoint)
        self.stub = pbg.EmulatorControllerStub(self.channel)
        self.metadata = [("authorization", f"Bearer {token}")] if token else []

    def send(self, touches):
        """touches: [(id, x, y, pressure), ...]"""
        event = pb.TouchEvent(
            touches=[pb.Touch(x=int(x), y=int(y), identifier=int(i), pressure=float(p)) for i, x, y, p in touches]
        )
        self.stub.sendTouch(event, metadata=self.metadata, timeout=5)

    def tap(self, x, y, ms=80):
        self.send([(0, x, y, 1.0)])
        time.sleep(ms / 1000)
        self.send([(0, x, y, 0.0)])

    def down(self, i, x, y):
        self.send([(i, x, y, 1.0)])

    def move(self, i, x, y):
        self.send([(i, x, y, 1.0)])

    def up(self, i):
        self.send([(i, 0, 0, 0.0)])


def android_sees_touch(serial):
    """True if Android's input dispatcher has a pointer down right now."""
    out = subprocess.run(
        [ADB, "-s", serial, "shell", "dumpsys", "input"],
        capture_output=True,
        text=True,
        timeout=20,
    ).stdout
    for line in out.splitlines():
        if "down=true" in line:
            return True
    return False


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--endpoint", default="127.0.0.1:8554")
    parser.add_argument("--token-file", default="")
    parser.add_argument("--serial", default="emulator-5554")
    args = parser.parse_args()

    token = ""
    if args.token_file:
        with open(args.token_file, encoding="utf-8") as f:
            token = f.read().strip()

    touch = EmuTouch(args.endpoint, token)
    print(json.dumps({"ok": True, "ready": True}), flush=True)

    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            cmd = json.loads(line)
            name = cmd.get("cmd")
            if name == "ping":
                reply = {"ok": True}
            elif name == "tap":
                touch.tap(cmd["x"], cmd["y"], cmd.get("ms", 80))
                reply = {"ok": True}
            elif name == "down":
                touch.down(cmd.get("id", 0), cmd["x"], cmd["y"])
                reply = {"ok": True}
            elif name == "move":
                touch.move(cmd.get("id", 0), cmd["x"], cmd["y"])
                reply = {"ok": True}
            elif name == "up":
                touch.up(cmd.get("id", 0))
                reply = {"ok": True}
            elif name == "selftest":
                # Hold a finger down, then ask Android whether it saw a pointer.
                x, y = cmd.get("x", 1200), cmd.get("y", 1000)
                touch.down(0, x, y)
                time.sleep(0.15)
                seen = android_sees_touch(args.serial)
                touch.up(0)
                reply = {"ok": seen, "why": None if seen else "Android reported no pointer down"}
            else:
                reply = {"ok": False, "why": f"unknown command {name!r}"}
        except Exception as e:  # noqa: BLE001 - the driver needs to see every failure
            reply = {"ok": False, "why": f"{type(e).__name__}: {e}"}
        print(json.dumps(reply), flush=True)


if __name__ == "__main__":
    main()
