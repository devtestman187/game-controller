#!/usr/bin/env python3
"""Runs the session pipeline in this process and taps its encoded video (M15 opt2).

With SESSION_TAP=on the entrypoint starts this instead of gst-launch-1.0: the
same words go to Gst.parse_launchv (so each word means what gst-launch made of
it), the pipeline lives in this process, and the appsink the entrypoint's tap
branch ends in hands every access unit to the callbacks in `frame_callbacks`
and to the tap server (tap_server.py), whose clients are the pages the player
relay tunnels here (PROTOCOL.md).

Like `gst-launch-1.0 -e`, a stop signal sends EOS, waits up to EOS_WAIT_MS for
the pipeline to finish and then sets it to NULL. GStreamer's own logging and
the latency tracer still go to stderr, so the session's pipeline.log keeps the
records the sampler reads.
"""

import argparse
import signal
import sys
import time

import gi

gi.require_version("Gst", "1.0")
gi.require_version("GstApp", "1.0")
gi.require_version("GstVideo", "1.0")
from gi.repository import GLib, Gst, GstApp, GstVideo

import tap_frames
import tap_server

# The appsink the entrypoint's tap branch ends in (streaming/entrypoint.sh).
TAP_SINK_NAME = "tap"
# How long a stop may take before the pipeline is set to NULL anyway: the grace
# `gst-launch -e` gives the end of a stream.
EOS_WAIT_MS = 5000
# At most one force-key-unit request per this many microseconds, so a client
# that asks over and over cannot turn every frame into an IDR.
KEY_UNIT_MIN_INTERVAL_US = 200000
# How many of the first keyframes must carry their SPS and PPS before the tap
# tells a client that a keyframe is always a place to start decoding.
PARAMETER_SET_KEYFRAMES = 5


class TapRunner:
    """The session pipeline in this process, with the tap branch read from Python."""

    def __init__(self, pipeline, port):
        self.pipeline = pipeline
        # The tap server's port (PROTOCOL.md): the server listens on it, and a
        # run's log says which session owns which port.
        self.port = port
        self.tap = pipeline.get_by_name(TAP_SINK_NAME)
        if self.tap is None:
            raise ValueError("the pipeline has no appsink named %s" % TAP_SINK_NAME)
        self.frame_callbacks = []
        self.frames_seen = 0
        self.keyframes_seen = 0
        # What PROTOCOL.md's hello tells a client; None until the first SPS and
        # the first buffer that carries the frame rate in its caps.
        self.profile = None
        self.width = None
        self.height = None
        self.fps = None
        self.every_keyframe_has_parameters = None
        # Whether any buffer arrived out of order (DTS != PTS), which a player
        # with no reordering buffer cannot decode as it comes.
        self.has_reordering = False
        self.last_key_request_us = None
        self.key_request_pending = False
        self.exit_status = 0
        self.eos_timer_id = None
        self.finished = False
        self.loop = GLib.MainLoop()
        self.tap.connect("new-sample", self._on_new_sample)
        # The WebSocket server a page reaches through the relay's /tap: it is
        # given frames by _on_new_sample and asks for a keyframe through
        # request_key_unit (PROTOCOL.md).
        self.server = tap_server.TapServer(port, self.request_key_unit, self.info)

    def add_frame_callback(self, callback):
        """Calls `callback(frame_no, pts_us, is_key, data)` for every access unit."""
        self.frame_callbacks.append(callback)

    def info(self):
        """What the tap knows about the stream so far, as PROTOCOL.md's hello has it."""
        return {
            "profile": self.profile,
            "width": self.width,
            "height": self.height,
            "fps": self.fps,
            "sps_pps_on_every_keyframe": self.every_keyframe_has_parameters,
            "has_reordering": self.has_reordering,
            "frames": self.frames_seen,
            "keyframes": self.keyframes_seen,
        }

    def request_key_unit(self):
        """Asks the encoder for a keyframe at the next frame; True when taken.

        The force-key-unit event goes upstream to the encoder (from the pad
        _key_unit_pad finds), which makes the next frame an IDR
        (nvautogpuh264enc's own min-force-key-unit-interval defaults to 0). It
        is a serialised event,
        so GStreamer only lets it upstream from the streaming thread: the
        sample callback pushes it, with the next frame, and a request taken
        while frames are flowing is answered about 1/60 s later.
        """
        now_us = time.monotonic_ns() // 1000
        if (
            self.last_key_request_us is not None
            and now_us - self.last_key_request_us < KEY_UNIT_MIN_INTERVAL_US
        ):
            return False
        self.last_key_request_us = now_us
        self.key_request_pending = True
        return True

    def run(self):
        """Plays the pipeline until it ends or a signal stops it; returns the status."""
        bus = self.pipeline.get_bus()
        bus.add_signal_watch()
        bus.connect("message", self._on_bus_message)
        for signum in (signal.SIGTERM, signal.SIGINT):
            GLib.unix_signal_add(GLib.PRIORITY_HIGH, signum, self._on_signal, signum)
        # The server listens before the first frame, so a page that is already
        # open gets its hello and a keyframe as soon as one can be made.
        self.server.start()
        if self.pipeline.set_state(Gst.State.PLAYING) == Gst.StateChangeReturn.FAILURE:
            print("tap: the pipeline would not start", file=sys.stderr)
            self.server.stop()
            return 1
        print("tap: playing, the tap server's port is %d" % self.port, file=sys.stderr)
        self.loop.run()
        print("tap: stopped after %s" % self.info(), file=sys.stderr)
        return self.exit_status

    def _on_new_sample(self, sink):
        # No I/O here but the callbacks: the queue before this sink is leaky and
        # the sink drops, so a slow reader loses frames instead of stalling the
        # encoder (PROTOCOL.md, backlog rule).
        sample = sink.emit("pull-sample")
        if sample is None:
            return Gst.FlowReturn.EOS
        buf = sample.get_buffer()
        okay, mapped = buf.map(Gst.MapFlags.READ)
        if not okay:
            print("tap: a sample could not be read", file=sys.stderr)
            return Gst.FlowReturn.OK
        try:
            data = bytes(mapped.data)
        finally:
            buf.unmap(mapped)
        # The branch hands over AVC, the encoder's own layout: the caps filter
        # that would ask the parser for byte-stream stalls the pipeline (see the
        # opt2-1 report), so the conversion to the Annex B PROTOCOL.md promises
        # happens here, once per frame.
        try:
            data = tap_frames.avc_to_annexb(data)
        except ValueError as error:
            print("tap: an access unit could not be converted: %s" % error, file=sys.stderr)
            return Gst.FlowReturn.OK
        frame_no = self.frames_seen
        self.frames_seen += 1
        if buf.dts != Gst.CLOCK_TIME_NONE and buf.dts != buf.pts:
            self.has_reordering = True
        pts_us = buf.pts // Gst.USECOND if buf.pts != Gst.CLOCK_TIME_NONE else 0
        if self.key_request_pending:
            self.key_request_pending = False
            self._push_key_unit_event()
        is_key = tap_frames.is_keyframe(data)
        if is_key:
            self._learn_from_keyframe(data)
        if self.fps is None:
            self.fps = _frame_rate(sample)
        for callback in self.frame_callbacks:
            callback(frame_no, pts_us, is_key, data)
        self.server.publish(frame_no, pts_us, is_key, data)
        return Gst.FlowReturn.OK

    def _push_key_unit_event(self):
        pad = self._key_unit_pad()
        event = GstVideo.video_event_new_upstream_force_key_unit(Gst.CLOCK_TIME_NONE, True, 0)
        if pad is None or not pad.send_event(event):
            print("tap: the keyframe request could not be sent", file=sys.stderr)

    def _key_unit_pad(self):
        """The pad a keyframe request goes upstream from: the tee's, not the tap's.

        The tap's sink pad is where a decoder would ask from, but the h264parse
        above the tap refuses the event (send_event returns False there) and the
        encoder never sees it; from the tee's src pad that feeds this branch the
        request reaches the encoder (measured, see the opt2-1 report). The pad
        is found by walking the branch back to the element with more than one
        src pad, the tee, so a changed branch is followed without new names.
        """
        element = self.tap
        upstream = self._upstream_element(element)
        while upstream is not None and self._src_pad_count(upstream) == 1:
            element = upstream
            upstream = self._upstream_element(element)
        if upstream is None:
            return self.tap.get_static_pad("sink")
        for pad in element.pads:
            if pad.get_direction() == Gst.PadDirection.SINK and pad.get_peer() is not None:
                return pad.get_peer()
        return self.tap.get_static_pad("sink")

    @staticmethod
    def _src_pad_count(element):
        """How many src pads the element has (the tee has one per branch)."""
        return sum(1 for pad in element.pads if pad.get_direction() == Gst.PadDirection.SRC)

    @staticmethod
    def _upstream_element(element):
        """The element feeding this one's first linked sink pad, or None."""
        for pad in element.pads:
            if pad.get_direction() != Gst.PadDirection.SINK:
                continue
            peer = pad.get_peer()
            if peer is not None:
                return peer.get_parent_element()
        return None

    def _learn_from_keyframe(self, annexb):
        self.keyframes_seen += 1
        with_parameters = tap_frames.has_sps_and_pps(annexb)
        if self.keyframes_seen <= PARAMETER_SET_KEYFRAMES:
            if self.every_keyframe_has_parameters is None:
                self.every_keyframe_has_parameters = with_parameters
            else:
                self.every_keyframe_has_parameters &= with_parameters
        if self.profile is not None or not with_parameters:
            return
        sps, _ = tap_frames.extract_sps_pps(annexb)
        self.profile = tap_frames.profile_string(sps)
        self.width, self.height = tap_frames.frame_size(sps)
        print(
            "tap: stream is %s %dx%d" % (self.profile, self.width, self.height),
            file=sys.stderr,
        )

    def _on_signal(self, signum):
        print("tap: signal %d, sending EOS" % signum, file=sys.stderr)
        self.pipeline.send_event(Gst.Event.new_eos())
        if self.eos_timer_id is None:
            self.eos_timer_id = GLib.timeout_add(EOS_WAIT_MS, self._eos_wait_over)
        return GLib.SOURCE_CONTINUE

    def _eos_wait_over(self):
        print("tap: no EOS after %d ms, stopping the pipeline" % EOS_WAIT_MS, file=sys.stderr)
        self.eos_timer_id = None
        self._finish(0)
        return GLib.SOURCE_REMOVE

    def _on_bus_message(self, bus, message):
        kind = message.type
        if kind == Gst.MessageType.ERROR:
            error, debug = message.parse_error()
            print(
                "tap: pipeline error from %s: %s (%s)" % (message.src.get_name(), error.message, debug),
                file=sys.stderr,
            )
            self._finish(1)
        elif kind == Gst.MessageType.WARNING:
            warning, debug = message.parse_warning()
            print(
                "tap: pipeline warning from %s: %s (%s)" % (message.src.get_name(), warning.message, debug),
                file=sys.stderr,
            )
        elif kind == Gst.MessageType.EOS:
            print("tap: EOS, stopping the pipeline", file=sys.stderr)
            self._finish(0)
        elif kind == Gst.MessageType.ELEMENT:
            # Element messages carry what the elements announce (the virtual
            # screen's socket name among them), which the session's log reads.
            structure = message.get_structure()
            if structure is not None:
                print("tap: %s" % structure.to_string(), file=sys.stderr)

    def _finish(self, status):
        if self.finished:
            return
        self.finished = True
        self.exit_status = status
        if self.eos_timer_id is not None:
            GLib.source_remove(self.eos_timer_id)
            self.eos_timer_id = None
        # The clients get PROTOCOL.md's `end` and the port is given back before
        # the pipeline goes to NULL, so the session's log ends with the counters.
        self.server.log_stats()
        self.server.stop()
        self.pipeline.set_state(Gst.State.NULL)
        self.loop.quit()


def _frame_rate(sample):
    """The frame rate the encoder's caps carry, or None when they carry none.

    PROTOCOL.md's hello names the stream's rate as its frame rate; the encoder
    keeps the rate it was given in its output caps, so the tap reads it there
    rather than being told a second time.
    """
    caps = sample.get_caps()
    structure = caps.get_structure(0) if caps is not None else None
    if structure is None or not structure.has_field("framerate"):
        return None
    # `get_value` cannot hand a GstFraction to Python (it raises TypeError), so
    # the field is read as the three parts pygobject does convert.
    found, numerator, denominator = structure.get_fraction("framerate")
    if not found or denominator == 0:
        return None
    return int(numerator) if denominator == 1 else numerator / denominator


def parse_args(argv):
    """`--port N`, then `--`, then the pipeline's words as gst-launch gets them."""
    if "--" not in argv:
        raise ValueError("usage: tap_runner.py --port N -- <the pipeline's words>")
    split = argv.index("--")
    parser = argparse.ArgumentParser(description="Runs the session pipeline and taps its video.")
    parser.add_argument(
        "--port",
        type=int,
        required=True,
        help="the loopback port the tap server listens on (PROTOCOL.md: automation port + 1)",
    )
    args = parser.parse_args(argv[:split])
    words = argv[split + 1 :]
    if not words:
        raise ValueError("no pipeline words after --")
    return args.port, words


def main(argv):
    try:
        port, words = parse_args(argv)
    except ValueError as error:
        print("tap: %s" % error, file=sys.stderr)
        return 2
    Gst.init(None)
    try:
        # parse_launchv takes the words gst-launch would have split the pipeline
        # into, so `!`, links like `ws.` and every property mean the same.
        pipeline = Gst.parse_launchv(words)
    except GLib.Error as error:
        print("tap: the pipeline does not parse: %s" % error.message, file=sys.stderr)
        return 2
    try:
        runner = TapRunner(pipeline, port)
    except ValueError as error:
        print("tap: %s" % error, file=sys.stderr)
        return 2
    return runner.run()


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
