import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';

void main() {
  group('scrubText', () {
    test('replaces a player name with [name] and leaves the rest of the text', () {
      expect(scrubText('Ann won the round', {'Ann'}), '[name] won the round');
    });

    test('replaces every player name whatever its case', () {
      expect(scrubText('ann beat Bo at puzzle', {'Ann', 'Bo'}), '[name] beat [name] at puzzle');
    });

    test('replaces a longer name before a shorter one inside it', () {
      expect(scrubText('Anna and Ann played', {'Ann', 'Anna'}), '[name] and [name] played');
    });

    test('leaves text with no player name as it is', () {
      expect(scrubText('P1 won in 3 tries', {'Ann'}), 'P1 won in 3 tries');
    });

    test('ignores an empty name', () {
      expect(scrubText('Ann', {'', '  ', 'Ann'}), '[name]');
    });
  });

  group('scrubEvent', () {
    test('drops the user block, the server name and every ip address', () {
      final scrubbed = scrubEvent({
        'message': 'boom',
        'user': {'id': 'abc', 'username': 'Ann'},
        'server_name': 'living-room-pc',
        'extra': {'ip_address': '192.168.1.20', 'note': 'kept'},
      }, {});
      expect(scrubbed, {
        'message': 'boom',
        'extra': {'note': 'kept'},
      });
    });

    test('replaces player names in the message, exceptions, breadcrumb messages and data', () {
      final scrubbed = scrubEvent(
        {
          'message': 'Ann lost the game',
          'exception': {
            'values': [
              {'type': 'StateError', 'value': 'Ann sent a bad move'},
            ],
          },
          'breadcrumbs': {
            'values': [
              {
                'message': 'Ann joined',
                'data': {'player': 'Ann', 'round': 2},
              },
            ],
          },
        },
        {'Ann'},
      );
      expect(scrubbed, {
        'message': '[name] lost the game',
        'exception': {
          'values': [
            {'type': 'StateError', 'value': '[name] sent a bad move'},
          ],
        },
        'breadcrumbs': {
          'values': [
            {
              'message': '[name] joined',
              'data': {'player': '[name]', 'round': 2},
            },
          ],
        },
      });
    });

    test('leaves a report with no player names as it was', () {
      final report = <String, Object?>{
        'message': 'P1 lost the game',
        'extra': {'round': 2},
      };
      expect(scrubEvent(report, {'Ann'}), report);
    });

    test('leaves the report it is given as it was', () {
      final report = <String, Object?>{
        'message': 'Ann lost the game',
        'user': {'username': 'Ann'},
      };
      scrubEvent(report, {'Ann'});
      expect(report['message'], 'Ann lost the game');
      expect(report['user'], {'username': 'Ann'});
    });
  });
}
