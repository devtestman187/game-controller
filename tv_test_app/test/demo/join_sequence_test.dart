import 'package:connection/connection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tvtest/src/demo/join_sequence.dart';

/// The join pre-roll (docs/demo-video-runbook.md 2.3, and the G2/G5 takes):
/// every seat on a side, then Start, and nothing in between.
void main() {
  /// What the sequence asked for, in order, with the other seats' presses
  /// dropped: two seats pressing A at once is what leaves half the players
  /// behind.
  List<JoinStep> presses(JoinSequence seq, {Set<String> join = const {}, int untilMs = 30000}) {
    final seen = <JoinStep>[];
    final joined = <String>{...join};
    final holding = <String, JoinStep>{};
    var started = false;
    var startAt = -1;
    for (var ms = 0; ms < untilMs && !seq.done && !seq.failed; ms += 16) {
      final step = seq.tick(ms, joined: joined, started: started);
      if (step != null) {
        if (holding[step.seat] == null) {
          seen.add(step);
          holding[step.seat] = step;
        }
      } else {
        // A press ended: the TV answers it.
        for (final held in holding.values.toList()) {
          if (held.button == GamepadButton.a) {
            joined.add(held.seat);
          } else if (held.button == GamepadButton.start) {
            startAt = ms + 240; // The match object appears a moment later.
          }
          holding.remove(held.seat);
        }
      }
      if (startAt >= 0 && ms >= startAt) started = true;
    }
    return seen;
  }

  test('presses A for every seat in order, then Start, and nothing twice', () {
    final seq = JoinSequence(order: const ['P1', 'Bot 3', 'Bot 2', 'Bot 4'], startSeat: 'P1');
    final steps = presses(seq);
    expect(steps.map((s) => s.seat).toList(), ['P1', 'Bot 3', 'Bot 2', 'Bot 4', 'P1']);
    expect(steps.map((s) => s.button).toList(), [
      GamepadButton.a,
      GamepadButton.a,
      GamepadButton.a,
      GamepadButton.a,
      GamepadButton.start,
    ]);
    expect(seq.done, isTrue);
    expect(seq.failed, isFalse);
  });

  test('holds one press at a time', () {
    // Draw a press, then tick on: until it is released the sequence must keep
    // asking for that same seat and no other.
    final seq = JoinSequence(order: const ['P1', 'Bot 2', 'Bot 3'], pressMs: 120);
    final first = seq.tick(0, joined: const {}, started: false);
    expect(first?.seat, 'P1');
    for (var ms = 16; ms < 120; ms += 16) {
      final held = seq.tick(ms, joined: const {}, started: false);
      expect(held?.seat, 'P1', reason: 'at $ms ms');
    }
    expect(seq.tick(130, joined: const {}, started: false), isNull, reason: 'the press is released');
  });

  test('never presses A again for a seat that has joined', () {
    final seq = JoinSequence(order: const ['P1', 'Bot 2'], startSeat: 'Bot 2');
    final steps = presses(seq, join: const {}, untilMs: 20000);
    final aSeats = [
      for (final s in steps)
        if (s.button == GamepadButton.a) s.seat,
    ];
    expect(aSeats, ['P1', 'Bot 2']);
  });

  test('skips a seat that is already on a side', () {
    final seq = JoinSequence(order: const ['P1', 'Bot 2', 'Bot 3'], startSeat: 'P1');
    final steps = presses(seq, join: const {'P1'}, untilMs: 20000);
    expect(steps.map((s) => s.seat).toList(), ['Bot 2', 'Bot 3', 'P1']);
    expect(steps.last.button, GamepadButton.start);
  });

  test('does not press Start while a seat is missing: 3 A presses, then fails', () {
    final seq = JoinSequence(order: const ['P1', 'Bot 2'], startSeat: 'P1', attempts: 3);
    // Bot 2 never joins: mark only P1.
    final seen = <JoinStep>[];
    final joined = <String>{};
    var started = false;
    JoinStep? holding;
    for (var ms = 0; ms < 30000 && !seq.done && !seq.failed; ms += 16) {
      final step = seq.tick(ms, joined: joined, started: started);
      if (step != null) {
        if (holding == null) {
          seen.add(step);
          holding = step;
        }
      } else if (holding != null) {
        if (holding.seat == 'P1') joined.add('P1');
        holding = null;
      }
    }
    final aForBot2 = seen.where((s) => s.seat == 'Bot 2').length;
    expect(aForBot2, 3, reason: 'the runbook caps a failure at 3 attempts, got $aForBot2');
    expect(seen.any((s) => s.button == GamepadButton.start), isFalse, reason: 'Start with a seat missing');
    expect(seq.failed, isTrue);
    expect(seq.why, contains('Bot 2'));
    expect(seq.done, isFalse);
  });

  test('fails when the match does not start after Start', () {
    final seq = JoinSequence(order: const ['P1'], startSeat: 'P1', startTimeoutMs: 2000);
    final joined = {'P1'};
    var ms = 0;
    while (!seq.done && !seq.failed && ms < 10000) {
      seq.tick(ms, joined: joined, started: false);
      ms += 16;
    }
    expect(seq.failed, isTrue);
    expect(seq.why, contains('did not start'));
  });

  test('a match that appears without Start still ends the sequence', () {
    final seq = JoinSequence(order: const ['P1', 'Bot 2']);
    seq.tick(0, joined: const {}, started: false);
    expect(seq.tick(16, joined: const {'P1', 'Bot 2'}, started: true), isNull);
    expect(seq.done, isTrue);
  });
}
