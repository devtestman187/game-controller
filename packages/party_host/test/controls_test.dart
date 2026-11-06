import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';

void main() {
  test('with no claims the controllers work the menus', () {
    final claims = ControlsClaims();
    expect(claims.current.menus, isTrue);
    expect(claims.current.only, isNull);
    expect(claims.current.layout, isNull);
  });

  test('the newest claim wins', () {
    final claims = ControlsClaims();
    final game = claims.claim(const Controls.game());
    final menus = const Controls.menus(only: {'p1'});
    claims.claim(menus);
    expect(claims.current, same(menus));

    game.release();
    expect(claims.current, same(menus), reason: 'the newest claim is still on top');
  });

  test('releasing the newest claim gives the controllers back to the one below', () {
    final claims = ControlsClaims();
    final game = const Controls.game();
    claims.claim(game);
    final menus = claims.claim(const Controls.menus(only: {'p1'}));
    expect(claims.current.menus, isTrue);

    menus.release();
    expect(claims.current, same(game));
    expect(claims.current.menus, isFalse);
  });

  test('releasing a claim in the middle leaves the newest one on top', () {
    final claims = ControlsClaims();
    claims.claim(const Controls.game());
    final middle = claims.claim(const Controls.menus(only: {'p1'}));
    final newest = claims.claim(const Controls.menus(only: {'p2'}));

    middle.release();
    expect(claims.current.only, {'p2'});

    newest.release();
    expect(claims.current.menus, isFalse, reason: 'the game claim is the only one left');
  });

  test('releasing a claim twice does nothing the second time', () {
    final claims = ControlsClaims();
    final game = const Controls.game();
    final gameClaim = claims.claim(game);
    final menusClaim = claims.claim(const Controls.menus(only: {'p1'}));

    menusClaim.release();
    menusClaim.release();
    expect(claims.current, same(game), reason: 'the same claim, not a claim taken off twice');

    gameClaim.release();
    expect(claims.current.menus, isTrue, reason: 'with no claims left the menus are back');
  });

  test('updating a claim changes what the controllers do now', () {
    final claims = ControlsClaims();
    final claim = claims.claim(const Controls.game());
    final menus = const Controls.menus(only: {'p1'});

    claim.controls = menus;
    expect(claims.current, same(menus));
    expect(claims.current.only, {'p1'});
  });
}
