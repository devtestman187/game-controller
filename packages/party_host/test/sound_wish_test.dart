import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';

/// What the player has been asked for, kept apart from the engine (M13 design
/// section 8): a load still running or a restart after the app was in the
/// background carries it out again. Pure, so no audio device is needed.
void main() {
  test('a loop starts from nothing, and the same name again is no start', () {
    const wish = SoundWish();
    expect(wish.startsFrom(null), isNull);
    final music = wish.withLoop('lobby');
    expect(music.loop, 'lobby');
    expect(music.startsFrom(null), 'lobby', reason: 'nothing plays, so it starts');
    expect(music.startsFrom('lobby'), isNull, reason: 'already playing, so it never restarts');
    expect(music.stopsFrom(null), isFalse);
    expect(music.stopsFrom('lobby'), isFalse);
  });

  test('another loop stops the old one first, and stopping leaves none wanted', () {
    const wish = SoundWish(loop: 'lobby');
    expect(wish.withLoop('countdown').stopsFrom('lobby'), isTrue);
    final none = wish.withLoop(null);
    expect(none.loop, isNull);
    expect(none.stopsFrom('lobby'), isTrue);
    expect(none.startsFrom('lobby'), isNull);
    expect(none.startsFrom(null), isNull);
  });

  test('after a restart the wanted loop starts again, at the volume still set', () {
    // The wish outlives the engine: a restart asks for what it asked for
    // before, now that nothing sounds.
    final wished = const SoundWish().withLoop('lobby').withVolume(0.3);
    expect(wished.startsFrom(null), 'lobby');
    expect(wished.volume, 0.3);
  });

  test('both volumes are clamped to silence and to full', () {
    expect(const SoundWish().withVolume(1.4).volume, 1.0);
    expect(const SoundWish().withVolume(-0.2).volume, 0.0);
    expect(const SoundWish().withMusicVolume(1.4).musicVolume, 1.0);
    expect(const SoundWish().withMusicVolume(-0.2).musicVolume, 0.0);
  });

  test('the music volume is its own, and survives the loop changing', () {
    final wish = const SoundWish().withVolume(0.8).withMusicVolume(0.4).withLoop('lobby').withLoop(null);
    expect(wish.volume, 0.8);
    expect(wish.musicVolume, 0.4);
  });

  test('the real player keeps what it is asked for without an engine', () async {
    final player = SoLoudSoundPlayer();
    player.volume = 0.3;
    player.musicVolume = 0.2;
    expect(player.volume, 0.3, reason: 'kept before the sounds are in');
    expect(player.musicVolume, 0.2);
    player.playLoop('lobby');
    player.stopLoop();
    await player.dispose();
  });
}
