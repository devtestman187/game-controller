import 'package:controller/src/discovery.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final startedAt = DateTime(2026, 11, 26, 12);

  test('the first-host line says 0 ms when the first screen answers at once', () {
    expect(firstHostLine(startedAt, startedAt), 'First screen found 0 ms after the search started');
  });

  test('the first-host line counts whole milliseconds, 1 ms after one millisecond', () {
    expect(
      firstHostLine(startedAt, startedAt.add(const Duration(milliseconds: 1))),
      'First screen found 1 ms after the search started',
    );
  });

  test('the first-host line counts 1234 ms after 1234 milliseconds', () {
    expect(
      firstHostLine(startedAt, startedAt.add(const Duration(milliseconds: 1234))),
      'First screen found 1234 ms after the search started',
    );
  });
}
