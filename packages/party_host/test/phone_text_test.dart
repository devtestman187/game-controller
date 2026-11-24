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
}
