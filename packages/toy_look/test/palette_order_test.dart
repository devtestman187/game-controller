import 'package:flutter_test/flutter_test.dart';
import 'package:protocol/protocol.dart' show PlayerCharacter;
import 'package:toy_look/toy_look.dart';

/// The protocol's colour IDs (M16 identity) and the look's colour names list the
/// same six colours. A character's ID and its spoken name must use the same word
/// for each slot, so the two lists must agree slot by slot.
void main() {
  test('each slot\'s colour ID is the look\'s colour name in lower case, for all six slots', () {
    const slots = ToyCharacter.lastSlot - ToyCharacter.firstSlot + 1;
    expect(PlayerCharacter.colourIds, hasLength(slots));
    expect(ToyCharacter.colourNames, hasLength(slots));
    for (var slot = ToyCharacter.firstSlot; slot <= ToyCharacter.lastSlot; slot++) {
      final id = PlayerCharacter.colourIds[slot - PlayerCharacter.firstSlot];
      final name = ToyCharacter.colourNames[slot - ToyCharacter.firstSlot];
      expect(id, name.toLowerCase(), reason: 'slot $slot');
    }
  });
}
