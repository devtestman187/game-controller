import 'dart:convert';

import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

/// A card as the wire carries it, with the fields a test changes.
Map<String, Object?> _card(String id, {int? maxCount, Object? title = 'Save'}) => {
  'id': id,
  'title': title,
  'maxCount': ?maxCount,
};

/// A choice round as the wire carries it, with the given cards.
Map<String, Object?> _choices(List<Object?> cards) => {'round': 1, 'title': 'Shop', 'cards': cards, 'endsInMs': 5000};

void main() {
  const codec = MessageCodec();

  // A round with a costed card, a card that takes up to three, and a greyed-out card.
  const shop = ChoicesMessage(
    round: 2,
    title: 'Shop',
    cards: [
      ChoiceCard(id: 'save', title: 'Save +2', detail: 'Adds 2 next round', cost: 2),
      ChoiceCard(id: 'build', title: 'Build', maxCount: 3),
      ChoiceCard(id: 'roadworks', title: 'Roadworks', enabled: false),
    ],
    endsInMs: 5000,
    defaultId: 'save',
    currency: 'Bolts',
    picked: 'build',
    pickedCount: 2,
    locked: true,
  );

  group('the choices messages through the codec', () {
    test('a round with three cards, a default, a pick and a lock round-trips', () {
      final decoded = codec.decode(codec.encode(shop)) as ChoicesMessage;
      expect(decoded, shop);
      expect(decoded.cards[1].maxCount, 3);
      expect(decoded.cards[2].enabled, isFalse);
      expect(decoded.pickedCount, 2);
      expect(decoded.locked, isTrue);
    });

    test('a card with and without a detail and a cost round-trips, and a null one writes no key', () {
      const full = ChoiceCard(id: 'save', title: 'Save +2', detail: 'Adds 2', cost: 2);
      const bare = ChoiceCard(id: 'vote', title: 'Vote');
      expect(ChoiceCard.fromJson(full.toJson()), full);
      expect(ChoiceCard.fromJson(bare.toJson()), bare);
      expect(bare.toJson().containsKey('detail'), isFalse);
      expect(bare.toJson().containsKey('cost'), isFalse);
      expect(bare.toJson()['maxCount'], 1);
      expect(bare.toJson()['enabled'], isTrue);
    });

    test('a round with nothing picked and no default writes no pick keys and reads back', () {
      const open = ChoicesMessage(
        round: 3,
        title: 'Vote',
        cards: [ChoiceCard(id: 'yes', title: 'Yes')],
        endsInMs: 1,
      );
      final json = jsonDecode(codec.encode(open)) as Map<String, Object?>;
      expect(json.containsKey('picked'), isFalse);
      expect(json.containsKey('defaultId'), isFalse);
      expect(codec.decode(codec.encode(open)), open);
    });

    test('a pick round-trips, and a cleared pick (null) keeps its null', () {
      const pick = ChoicePickMessage(round: 2, pick: 'build', count: 2, locked: true);
      const clear = ChoicePickMessage(round: 2);
      expect(codec.decode(codec.encode(pick)), pick);
      expect(codec.decode(codec.encode(clear)), clear);
      expect((codec.decode(codec.encode(clear)) as ChoicePickMessage).pick, isNull);
      expect((codec.decode(codec.encode(clear)) as ChoicePickMessage).count, 1);
    });

    test('an end round-trips with a result and with none', () {
      const applied = ChoicesEndMessage(round: 2, result: 'save', count: 1, byDefault: true);
      const abstained = ChoicesEndMessage(round: 2, count: 0, byDefault: false);
      expect(codec.decode(codec.encode(applied)), applied);
      expect(codec.decode(codec.encode(abstained)), abstained);
      expect((codec.decode(codec.encode(abstained)) as ChoicesEndMessage).result, isNull);
    });

    test('the three wire types and the capability are named as the contract says', () {
      expect(ChoicesMessage.wireType, 'choices');
      expect(ChoicePickMessage.wireType, 'choice_pick');
      expect(ChoicesEndMessage.wireType, 'choices_end');
      expect(Capability.choices, 'choices');
    });

    test('extra fields a newer host adds are ignored', () {
      final json = jsonDecode(codec.encode(shop)) as Map<String, Object?>;
      json['futureField'] = 'x';
      final decoded = ChoicesMessage.fromPayload(json);
      expect(decoded, shop);
    });
  });

  group('a bad choices payload is a FormatException', () {
    test('a card with an empty id is rejected', () {
      expect(() => ChoicesMessage.fromPayload(_choices([_card('')])), throwsFormatException);
    });

    test('two cards with the same id are rejected', () {
      expect(() => ChoicesMessage.fromPayload(_choices([_card('a'), _card('a')])), throwsFormatException);
    });

    test('a round with no cards is rejected', () {
      expect(() => ChoicesMessage.fromPayload(_choices([])), throwsFormatException);
    });

    test('a round with seven cards is rejected, and six is the most', () {
      final six = [for (var i = 0; i < 6; i++) _card('c$i')];
      final seven = [for (var i = 0; i < 7; i++) _card('c$i')];
      expect(ChoicesMessage.fromPayload(_choices(six)).cards, hasLength(6));
      expect(() => ChoicesMessage.fromPayload(_choices(seven)), throwsFormatException);
    });

    test('a card with a maxCount of 0 is rejected', () {
      expect(() => ChoicesMessage.fromPayload(_choices([_card('a', maxCount: 0)])), throwsFormatException);
    });

    test('a card with a maxCount of 10 is rejected, and 9 is the most', () {
      expect(ChoicesMessage.fromPayload(_choices([_card('a', maxCount: 9)])).cards.single.maxCount, 9);
      expect(() => ChoicesMessage.fromPayload(_choices([_card('a', maxCount: 10)])), throwsFormatException);
    });

    test('a card whose title is not a string is rejected', () {
      expect(() => ChoicesMessage.fromPayload(_choices([_card('a', title: 3)])), throwsFormatException);
    });

    test('a pick with a non-integer round is rejected', () {
      expect(() => ChoicePickMessage.fromPayload({'round': 'two'}), throwsFormatException);
    });

    test('an end with no count is rejected', () {
      expect(() => ChoicesEndMessage.fromPayload({'round': 2, 'byDefault': true}), throwsFormatException);
    });
  });
}
