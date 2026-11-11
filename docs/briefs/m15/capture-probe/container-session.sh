#!/bin/bash
# One Thumb Party streaming session inside a container: a virtual screen that
# is a GStreamer source (gst-wayland-display), the TV app drawing into it, a
# PulseAudio null sink for the game's sound, and NVENC encoding video + Opus.
# $1 = session number (1 or 2), used for the output file name.
set -u
n="${1:-1}"
export XDG_RUNTIME_DIR=/tmp/xdg
rm -rf "$XDG_RUNTIME_DIR"
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"
mkdir -p /out

printf 'pcm.!default { type pulse }\nctl.!default { type pulse }\n' > /etc/asound.conf
mkdir -p /tmp/pulse
chmod 777 /tmp/pulse
pulseaudio --system --daemonize=yes --disallow-exit --exit-idle-time=-1 -n \
  --load="module-native-protocol-unix auth-anonymous=1 socket=/tmp/pulse/native" \
  --load="module-null-sink sink_name=party sink_properties=device.description=Party" \
  --load="module-always-sink" > /tmp/pulse.log 2>&1
export PULSE_SERVER=unix:/tmp/pulse/native

export LD_LIBRARY_PATH=/opt/wayland124/lib/x86_64-linux-gnu:/usr/lib/wsl/lib
export GST_PLUGIN_PATH=/usr/local/lib/gstreamer-1.0
export GST_REGISTRY=/tmp/reg.bin
export GALLIUM_DRIVER=d3d12
export MESA_D3D12_DEFAULT_ADAPTER_NAME=NVIDIA

setsid nohup gst-launch-1.0 -e \
  waylanddisplaysrc render-node=software ! video/x-raw,width=1920,height=1080,framerate=60/1 ! videoconvert \
  ! nvautogpuh264enc ! h264parse ! queue ! mux. \
  pulsesrc device=party.monitor ! queue ! audioconvert ! audioresample ! opusenc ! queue ! mux. \
  matroskamux name=mux ! filesink location="/out/session$n.mkv" > /tmp/pipe.log 2>&1 &

for i in $(seq 1 60); do
  sock=$(ls "$XDG_RUNTIME_DIR" 2>/dev/null | grep -v lock | head -1)
  [ -n "$sock" ] && break
  sleep 0.5
done
echo "socket=$sock"
export WAYLAND_DISPLAY="$sock" GDK_BACKEND=wayland
cd /app
setsid nohup ./tvtest > /tmp/app.log 2>&1 &
sleep 12
grep -a -o 'code=[0-9]*' /tmp/app.log | head -1
