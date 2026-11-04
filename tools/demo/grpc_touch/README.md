# gRPC touch helper

The demo video's touch driver needs multi-touch at 60 Hz on the Android
emulator. Raw `/dev/input` injection proved unreliable here (it stopped
reaching the device after an emulator reboot, silently), so this uses the
emulator's gRPC control port instead: it takes touches in **display pixels**,
with no raw-axis or rotation arithmetic.

## Setup (once)

```bash
# The work folder's venv, not a new one.
../..\..\thumbparty-demo\venv\Scripts\python.exe -m pip install grpcio grpcio-tools

# Generate the stubs from the SDK's proto.
cd tools/demo/grpc_touch
python -m grpc_tools.protoc -I"%LOCALAPPDATA%\Android\Sdk\emulator\lib" \
    --python_out=. --grpc_python_out=. emulator_controller.proto
```

The generated `emulator_controller_pb2*.py` files are committed so a fresh
checkout runs without regenerating.

## Running

The emulator must be started with the gRPC bridge:

```bash
emulator -avd m7_android12 -gpu host -grpc 8554 -grpc-use-token -port 5554
```

then:

```bash
python touch_server.py --endpoint 127.0.0.1:8554 \
    --token-file C:\Users\singh\.emulator_console_auth_token
```

It prints `{"ok": true, "ready": true}` and then reads one JSON command per
line on stdin, answering one JSON line per command.

| Command | Does |
| --- | --- |
| `{"cmd":"ping"}` | `{"ok":true}` |
| `{"cmd":"tap","x":2000,"y":73,"ms":80}` | finger down, hold, up |
| `{"cmd":"down","id":0,"x":266,"y":520}` | a finger down at a display point |
| `{"cmd":"move","id":0,"x":300,"y":560}` | move that finger |
| `{"cmd":"up","id":0}` | lift it |
| `{"cmd":"selftest"}` | hold a touch, ask Android's input dispatcher whether it saw a pointer, release; `ok` is the answer |

## Why the self-test matters

Raw injection once worked, then silently did nothing after an emulator reboot.
Every take must fail loudly instead: the touch driver runs `selftest` before a
shot and refuses to record when it comes back `ok: false`.
