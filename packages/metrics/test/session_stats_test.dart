import 'package:metrics/metrics.dart';
import 'package:test/test.dart';

void main() {
  group('delay stats', () {
    test('median, 95th percentile and max', () {
      final d = DelayStats();
      for (var i = 1; i <= 100; i++) {
        d.add(i);
      }
      expect(d.median, 51);
      expect(d.p95, 95);
      expect(d.maxValue, 100);
      expect(d.toJson(), {'n': 100, 'median': 51, 'p95': 95, 'max': 100});
    });

    test('values past the histogram still give the right max', () {
      final d = DelayStats()
        ..add(5)
        ..add(9000);
      expect(d.maxValue, 9000);
      expect(d.quantile(1), 9000);
    });

    test('no samples, no stats', () => expect(DelayStats().toJson(), isNull));
  });

  group('rating scheduler', () {
    // The prompt always goes out when due.
    bool askIfDue(RatingScheduler s, String id, int atMs) {
      final due = s.gameEnded(id, atMs);
      if (due) s.asked(id, atMs);
      return due;
    }

    test('a player who could not be asked (an older phone) stays due, and is asked as soon as possible', () {
      final s = RatingScheduler();
      // Rounds 1 to 6 on an M8 phone: due from round 3, but never asked.
      final due = [for (var game = 1; game <= 6; game++) s.gameEnded('p1', game * 6000)];
      expect(due, [false, false, true, true, true, true]);
      // The updated phone takes the next round's prompt at once.
      expect(askIfDue(s, 'p1', 50000), isTrue);
      expect(askIfDue(s, 'p1', 56000), isFalse);
    });

    test('first after three games, then every five games and at least three minutes apart', () {
      final s = RatingScheduler();
      final asked = [for (var game = 1; game <= 20; game++) askIfDue(s, 'p1', game * 60 * 1000)];
      // Games 3, then 8 (5 later, 5 min later), 13, 18.
      expect(
        [
          for (var i = 0; i < asked.length; i++)
            if (asked[i]) i + 1,
        ],
        [3, 8, 13, 18],
      );
    });

    test('quick games wait for the time gap', () {
      final s = RatingScheduler();
      final asked = [for (var game = 1; game <= 30; game++) askIfDue(s, 'p1', game * 10 * 1000)];
      // Game 3 at 30 s; then not before 3 minutes later (game 21 at 210 s).
      expect(
        [
          for (var i = 0; i < asked.length; i++)
            if (asked[i]) i + 1,
        ],
        [3, 21],
      );
    });

    test('players are counted separately', () {
      final s = RatingScheduler();
      askIfDue(s, 'p1', 0);
      askIfDue(s, 'p1', 0);
      expect(askIfDue(s, 'p2', 0), isFalse);
      expect(askIfDue(s, 'p1', 0), isTrue);
    });
  });
}
