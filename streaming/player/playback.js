/*
 * The two elements the page plays on (M15 fix7): the picture in the video
 * element and, whenever the session sends sound at all, the sound on an audio
 * element of its own. One element carrying both would hold the picture back to
 * match the sound's larger buffer; two keep their own.
 */

/**
 * What the page is showing: one video element and one audio element, filled
 * from the streams the TV sends. The browser's autoplay rules are the reason
 * it starts muted and is unmuted a step later.
 */
export class Playback {
  /**
   * @param {object} parts
   * @param {HTMLVideoElement} parts.screen - the element the picture plays in
   * @param {HTMLAudioElement} parts.sound - the element the sound plays in
   */
  constructor({ screen, sound }) {
    this._screen = screen;
    this._sound = sound;
    this._picture = null;
    this._soundStream = null;
  }

  /** Whether the sound being played has a stream of its own. */
  get hasSound() {
    return this._soundStream !== null;
  }

  /**
   * Plays [picture] and, on the audio element, [sound]; a null [sound] is a
   * stream without sound (SESSION_AUDIO=off) and leaves the element empty.
   * The streams already playing are not set again, so a sound that arrives
   * late does not restart the picture.
   */
  show(picture, sound) {
    if (picture !== this._picture) {
      this._picture = picture;
      this._screen.srcObject = picture;
    }
    if (sound !== this._soundStream) {
      this._soundStream = sound;
      this._sound.srcObject = sound;
    }
  }

  /**
   * Starts the picture muted, which every browser allows without a tap;
   * throws when the picture will not start at all.
   */
  async startMuted() {
    this._screen.muted = true;
    this._sound.muted = true;
    await this._screen.play();
  }

  /**
   * Unmutes and starts the sound too; throws when the browser wants a tap
   * first, so the page can show its button. A stream without sound plays
   * unmuted and needs no tap, so no button appears for it.
   */
  async unmute() {
    this._screen.muted = false;
    this._sound.muted = !this.hasSound;
    if (this.hasSound) await this._sound.play();
    await this._screen.play();
  }

  /** Stops both elements and forgets the streams; a reconnect starts clean. */
  clear() {
    this._screen.pause();
    this._screen.srcObject = null;
    this._sound.pause();
    this._sound.srcObject = null;
    this._picture = null;
    this._soundStream = null;
  }
}

/**
 * The picture's stream on its own when the tracks are split, so the video
 * element's buffer holds no audio to wait for.
 * @param {MediaStream} stream
 * @param {boolean} splitTracks
 * @returns {MediaStream}
 */
export function pictureOf(stream, splitTracks) {
  if (!splitTracks) return stream;
  const tracks = stream.getVideoTracks();
  return tracks.length === 0 ? stream : new MediaStream(tracks);
}

/**
 * The sound to play on the audio element: the sound producer's own stream when
 * the session sends one (SESSION_AUDIO=separate), the picture's audio tracks
 * when only the elements are split, and null when the stream has no sound.
 * @param {MediaStream} stream - the picture's stream
 * @param {boolean} splitTracks
 * @param {MediaStream|null} soundStream - the sound producer's stream, if any
 * @returns {MediaStream|null}
 */
export function soundOf(stream, splitTracks, soundStream) {
  if (soundStream !== null) return soundStream;
  if (stream === null || !splitTracks) return null;
  const tracks = stream.getAudioTracks();
  return tracks.length === 0 ? null : new MediaStream(tracks);
}
