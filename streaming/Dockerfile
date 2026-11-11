# syntax=docker/dockerfile:1
#
# The Thumb Party session image (M15): one container is one household session.
# It draws the TV app on a virtual screen that is also the video source
# (gst-wayland-display), encodes it with NVENC and sends picture and sound over
# WebRTC (webrtcsink) to the player page this image also serves. The design and
# the measurements behind it are in docs/design/streaming-custom.md and
# docs/briefs/m15/capture-probe-report.md; how to build and run it is in
# streaming/README.md, and tools/stream.sh does both.
#
# Build from the repository root (the context is the checkout):
#   docker build -f streaming/Dockerfile -t tp-session:latest .
#
# Stages: player-api (the browser client), flutter-bundle (the app),
# gst-plugins (the virtual screen and WebRTC, both hand-built) and runtime.
#
# Every version is pinned, and each pin says why.

# Ubuntu 24.04 is the distro every M15 probe measured on (GStreamer 1.24.2,
# Mesa 25.2.8). The digest pins the exact image, not just the tag.
ARG UBUNTU_IMAGE=ubuntu:24.04@sha256:fe81560990fae86dc4743202b2cb4d3df98d0bcf949173cecef15ce1127ef852

# --- the web player's client: gst-plugins-rs' own gstwebrtc-api ------------
# It is a webpack build, so it is built here once and served as plain
# JavaScript; the player page itself has no build step. Node 22 is the LTS the
# bundle is built and tested with upstream.
FROM node:22-bookworm-slim@sha256:18052396bf1d0c6e0a8c58181b5c1457da19409efbd5032a3f4d86974e74d13c AS player-api

# The webrtc client ships with the same gst-plugins-rs release as webrtcsink.
ARG GST_PLUGINS_RS_VERSION=0.13.6

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl xz-utils \
 && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /src \
 && curl -fsSL -o /tmp/gst-plugins-rs.tar.gz \
      "https://gitlab.freedesktop.org/gstreamer/gst-plugins-rs/-/archive/${GST_PLUGINS_RS_VERSION}/gst-plugins-rs-${GST_PLUGINS_RS_VERSION}.tar.gz" \
 && tar -xzf /tmp/gst-plugins-rs.tar.gz -C /src --strip-components=1 \
 && rm /tmp/gst-plugins-rs.tar.gz

WORKDIR /src/net/webrtc/gstwebrtc-api
# `npm run build` writes dist/gstwebrtc-api-<version>.min.js, the global
# `GstWebRTCAPI` the player page loads.
RUN npm install --no-audit --no-fund && npm run build

# --- the TV app: a Linux release bundle ------------------------------------
# Flutter's own Linux toolchain needs the GTK development headers; the app is
# built from this checkout, so the image is the app as committed.
FROM ${UBUNTU_IMAGE} AS flutter-bundle

# Flutter 3.47.8 is the version .github/workflows/release.yml pins, so the
# streamed app is built by the same toolchain as the store builds. The checksum
# is of the tarball at that URL.
ARG FLUTTER_VERSION=3.47.8
ARG FLUTTER_SHA256=baf7dcc5a3dbba60fe863bf493a6cf203195621f7786eaa5a1bba02cd0d87dd2

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl git unzip xz-utils file \
      clang cmake ninja-build pkg-config \
      libgtk-3-dev liblzma-dev libstdc++-13-dev libasound2-dev libpulse-dev \
      libavahi-compat-libdnssd-dev libsecret-1-dev libjsoncpp-dev \
      libglu1-mesa-dev libegl1-mesa-dev libgles2-mesa-dev \
 && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL -o /tmp/flutter.tar.xz \
      "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
 && echo "${FLUTTER_SHA256}  /tmp/flutter.tar.xz" | sha256sum -c - \
 && tar -xJf /tmp/flutter.tar.xz -C /opt \
 && rm /tmp/flutter.tar.xz

ENV PATH=/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:$PATH

WORKDIR /src
# Only what the app's build reads: the pub workspace's pubspecs (the other
# members are resolved, not built) and the folders that hold code. Touching the
# player page, the scripts or the docs must not throw away these minutes, and
# `tv_test_app/build/` never gets in (a CMake cache from another machine's build
# would make this step fail).
COPY pubspec.yaml pubspec.lock ./
COPY controller_app/pubspec.yaml controller_app/pubspec.yaml
COPY assets/ assets/
COPY packages/ packages/
COPY tv_test_app/pubspec.yaml tv_test_app/pubspec.yaml
COPY tv_test_app/lib/ tv_test_app/lib/
COPY tv_test_app/linux/ tv_test_app/linux/
# The same for pub's leftovers in a working tree.
RUN find /src -name .dart_tool -type d -prune -exec rm -rf {} +
# The release archive keeps the SDK's .git, which git only trusts after being
# told to. The first build downloads flutter_soloud's native libraries and asks
# for a rerun (docs/briefs/m15/linux-game-probe-report.md section 3.4).
RUN git config --global --add safe.directory /opt/flutter \
 && flutter --disable-analytics \
 && flutter config --enable-linux-desktop \
 && flutter pub get \
 && cd tv_test_app \
 && { flutter build linux --release || flutter build linux --release; }

# --- the virtual screen and the WebRTC sender ------------------------------
# Three hand-built pieces from the capture probe:
#  - libwayland 1.24.0, because gst-wayland-display calls
#    wl_client_set_max_buffer_size, which Ubuntu 24.04's 1.22 does not export;
#  - gst-wayland-display at the last commit that builds against GStreamer 1.24
#    (later ones want the GStreamer 1.28 bindings);
#  - gst-plugins-rs 0.13.6 for webrtcsink (no apt package exists for 1.24).
FROM ${UBUNTU_IMAGE} AS gst-plugins

ARG WAYLAND_VERSION=1.24.0
ARG GST_WAYLAND_DISPLAY_COMMIT=016b4fc66d62b6a34c37169ecf6d511eef140d7c
ARG GST_PLUGINS_RS_VERSION=0.13.6
# The toolchain the capture probe built these with (rustc 1.99.1).
ARG RUST_VERSION=1.99.1

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl git xz-utils build-essential pkg-config python3 \
      meson ninja-build clang libclang-dev libssl-dev \
      libexpat1-dev libffi-dev libxml2-dev \
      libdrm-dev libgbm-dev libegl-dev libgles-dev libxkbcommon-dev libudev-dev libinput-dev \
      libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev libgstreamer-plugins-bad1.0-dev \
 && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /src \
 && curl -fsSL -o /tmp/wayland.tar.xz \
      "https://gitlab.freedesktop.org/wayland/wayland/-/releases/${WAYLAND_VERSION}/downloads/wayland-${WAYLAND_VERSION}.tar.xz" \
 && tar -xJf /tmp/wayland.tar.xz -C /src \
 && cd "/src/wayland-${WAYLAND_VERSION}" \
 && meson setup build --prefix=/opt/wayland -Ddocumentation=false -Dtests=false \
 && ninja -C build install

# The plugin and everything built from here on links against that libwayland.
ENV PKG_CONFIG_PATH=/opt/wayland/lib/x86_64-linux-gnu/pkgconfig:/opt/wayland/share/pkgconfig
ENV LD_LIBRARY_PATH=/opt/wayland/lib/x86_64-linux-gnu

RUN curl -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain "${RUST_VERSION}"
ENV PATH=/root/.cargo/bin:$PATH

RUN mkdir -p /src/gst-wayland-display \
 && curl -fsSL -o /tmp/gst-wayland-display.tar.gz \
      "https://github.com/games-on-whales/gst-wayland-display/archive/${GST_WAYLAND_DISPLAY_COMMIT}.tar.gz" \
 && tar -xzf /tmp/gst-wayland-display.tar.gz -C /src/gst-wayland-display --strip-components=1 \
 && rm /tmp/gst-wayland-display.tar.gz

RUN cd /src/gst-wayland-display && cargo build --release -p gst-plugin-wayland-display

RUN mkdir -p /src/gst-plugins-rs \
 && curl -fsSL -o /tmp/gst-plugins-rs.tar.gz \
      "https://gitlab.freedesktop.org/gstreamer/gst-plugins-rs/-/archive/${GST_PLUGINS_RS_VERSION}/gst-plugins-rs-${GST_PLUGINS_RS_VERSION}.tar.gz" \
 && tar -xzf /tmp/gst-plugins-rs.tar.gz -C /src/gst-plugins-rs --strip-components=1 \
 && rm /tmp/gst-plugins-rs.tar.gz

# webrtcsink is the plugin; the signalling server is a second crate of the same
# release, and the element needs it as its own process (capture probe 3.7).
RUN cd /src/gst-plugins-rs \
 && cargo build --release -p gst-plugin-webrtc -p gst-plugin-webrtc-signalling

# --- the session ------------------------------------------------------------
# No build tools and no sources: GStreamer, PulseAudio, the app bundle, the
# hand-built plugins and the scripts, run as an ordinary user.
FROM ${UBUNTU_IMAGE} AS runtime

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates python3 \
      gstreamer1.0-tools gstreamer1.0-plugins-base gstreamer1.0-plugins-good \
      gstreamer1.0-plugins-bad gstreamer1.0-nice \
      pulseaudio alsa-utils \
      libgtk-3-0t64 libasound2t64 libpulse0 libsecret-1-0 libjsoncpp25 \
      libavahi-compat-libdnssd1 liblzma5 \
      libdrm2 libgbm1 libxkbcommon0 libinput10 \
      libglu1-mesa libegl1 libgles2 libgl1-mesa-dri \
 && rm -rf /var/lib/apt/lists/*

# libwayland 1.24 goes where the dynamic loader finds it, ahead of 1.22.
COPY --from=gst-plugins /opt/wayland/ /usr/local/
RUN ldconfig

COPY --from=gst-plugins /src/gst-wayland-display/target/release/libgstwaylanddisplaysrc.so /usr/local/lib/gstreamer-1.0/
COPY --from=gst-plugins /src/gst-plugins-rs/target/release/libgstrswebrtc.so /usr/local/lib/gstreamer-1.0/
COPY --from=gst-plugins /src/gst-plugins-rs/target/release/gst-webrtc-signalling-server /usr/local/bin/
ENV GST_PLUGIN_PATH=/usr/local/lib/gstreamer-1.0

COPY --from=flutter-bundle /src/tv_test_app/build/linux/x64/release/bundle /app
COPY --from=player-api /src/net/webrtc/gstwebrtc-api/dist/gstwebrtc-api-2.0.0.min.js /usr/share/thumb-party/player/lib/
COPY streaming/player/ /usr/share/thumb-party/player/
COPY streaming/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 0755 /usr/local/bin/entrypoint.sh

# The game's sound goes to PulseAudio: miniaudio reaches it through ALSA
# (capture probe 3.5).
RUN printf 'pcm.!default { type pulse }\nctl.!default { type pulse }\n' > /etc/asound.conf

# The session runs as `party`, never as root: /dev/dxg is world-writable in a
# WSL2 GPU container, so the GPU needs no privilege. The run directory holds the
# session's sockets and logs, so it belongs to that user too. (The number is
# left to useradd: the base image's own `ubuntu` account already has 1000.)
RUN useradd --user-group --create-home --shell /usr/sbin/nologin party \
 && mkdir -p /run/thumb-party \
 && chown party:party /run/thumb-party

USER party
WORKDIR /app

# The controller and the signalling and player ports are the defaults here;
# tools/stream.sh gives each session its own.
EXPOSE 45780 8443 8080

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
