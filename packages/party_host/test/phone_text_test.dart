import 'package:connection/connection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';

/// The phone string table's words a screen builds out of a value (M13 3b,
/// design section 7), beside the host's in host_text_test.dart.
void main() {
  test('a round place is said as an ordinal', () {
    expect(PhoneText.place(1), '1st');
    expect(PhoneText.place(2), '2nd');
    expect(PhoneText.place(3), '3rd');
    expect(PhoneText.place(4), '4th');
    // 11–13 take "th", whatever their unit's ending says.
    expect(PhoneText.place(11), '11th');
    expect(PhoneText.place(12), '12th');
    expect(PhoneText.place(13), '13th');
    // The twenties read off the unit again.
    expect(PhoneText.place(21), '21st');
    expect(PhoneText.place(22), '22nd');
    expect(PhoneText.place(23), '23rd');
  });

  test('the night\'s winner is named on the last round\'s card, or "You won the night!" for the winner', () {
    expect(PhoneText.youWonNight, 'You won the night!');
    expect(PhoneText.nightWinner('Mia and Dad'), 'Mia and Dad won the night!');
  });

  test('the last round\'s card says the awards are coming, in place of the standings', () {
    expect(PhoneText.awardsComing, 'Awards coming…');
  });

  test('the awards are headed "Awards", and an award nobody won says "Not won tonight"', () {
    expect(PhoneText.awardsHeading, 'Awards');
    expect(PhoneText.awardNotWon, 'Not won tonight');
  });

  test('an award is one line: its name, its winners and its points', () {
    expect(PhoneText.awardLine('Fastest', 'Mia', 3), 'Fastest: Mia (+3)');
    expect(PhoneText.awardLine('Cleanest', 'Dad and Ben', 3), 'Cleanest: Dad and Ben (+3)');
    expect(PhoneText.awardLine('Luckiest', PhoneText.awardNotWon, 0), 'Luckiest: Not won tonight');
  });

  test('a version mismatch says in plain words which app to update, for kids and parents', () {
    const mismatch = ClientSnapshot(status: ClientStatus.failed, problem: ClientProblem.versionMismatch);
    final text = PhoneText.problemText(mismatch);
    expect(
      text,
      'This phone app and the TV app are not the same version. Update the Thumb Party app on the TV, or on this '
      'phone (Android or iPhone), so both are new.',
    );
    expect(text!.length, lessThan(200), reason: 'a short line a phone screen fits');
    expect(text.toLowerCase(), isNot(contains('protocol')));
  });
}
