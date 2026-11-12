/*
 * The page's connections to the TV (M15 c1, fix7): one consumer session for
 * the picture and, when the session sends the sound apart from it
 * (SESSION_AUDIO=separate), a second one for the sound. Each brings its own
 * peer connection and its own stream id, so a browser has nothing to lip-sync
 * across them; a lost sound reconnects alone, and a new picture brings a new
 * sound with it.
 */

// How long to wait before asking for a stream again after it dropped: short
// enough that a person sees a blink, long enough that a server still starting
// up is not hammered.
const reconnectDelayMs = 1000;

// The producers a session labels when it sends the sound as its own stream
// (SESSION_AUDIO=separate in streaming/entrypoint.sh): the page tells them
// apart by these names, never by their order, so a session that sends one
// stream keeps working exactly as it did.
const pictureProducerName = "TP-Picture";
const soundProducerName = "TP-Sound";

/** A producer's meta name, or '' for one that sends none. */
function producerNameOf(producer) {
  const meta = producer === null ? null : producer.meta;
  return meta !== null && typeof meta.name === "string" ? meta.name : "";
}

/** The picture's producer and, when the session sends one, the sound's. */
function producersNow(api) {
  const producers = api.getAvailableProducers();
  const sound = producers.find((producer) => producerNameOf(producer) === soundProducerName) ?? null;
  const picture =
    producers.find((producer) => producerNameOf(producer) === pictureProducerName) ??
    producers.find((producer) => producer !== sound) ??
    null;
  return { picture, sound };
}

/** The page's two connections, kept together so one can drop without the other. */
export class StreamLinks {
  /**
   * @param {object} parts
   * @param {GstWebRTCAPI} parts.api - the signalling client
   * @param {object} parts.handlers - what the page does with what arrives:
   *   `pictureStream` and `soundStream` (a stream, and null when the sound is
   *   gone), `pictureReady` and `soundReady` (each with a peer connection),
   *   `status` and `problem` (a text), `reconnecting`, and `closed`
   */
  constructor({ api, handlers }) {
    this._api = api;
    this._handlers = handlers;
    this._picture = null;
    this._sound = null;
    this._reconnectTimer = null;
    this._soundTimer = null;
  }

  /** Connects to the picture's producer and, when there is one, the sound's. */
  connect() {
    const { picture, sound } = producersNow(this._api);
    if (picture === null) {
      this._handlers.status("waiting for the TV…");
      this.reconnect();
      return;
    }
    this._connectPicture(picture.id);
    if (sound !== null) this._connectSound(sound.id);
  }

  /** Asks for the picture again after a drop, and for the sound with it. */
  reconnect() {
    if (this._reconnectTimer !== null) {
      return;
    }
    this.close();
    this._handlers.reconnecting();
    this._reconnectTimer = window.setTimeout(() => {
      this._reconnectTimer = null;
      this.connect();
    }, reconnectDelayMs);
  }

  /** Ends both sessions and tells the page its streams are gone. */
  close() {
    if (this._soundTimer !== null) {
      window.clearTimeout(this._soundTimer);
      this._soundTimer = null;
    }
    this._closeSound();
    if (this._picture !== null) {
      const closing = this._picture;
      this._picture = null;
      closing.close();
    }
    this._handlers.closed();
  }

  _closeSound() {
    if (this._sound !== null) {
      const closing = this._sound;
      this._sound = null;
      closing.close();
    }
    this._handlers.soundStream(null);
  }

  // The sound asks for its stream again on its own: the picture's connection
  // is left as it is, so a lost sound costs the viewer a second of sound only.
  _soundReconnect() {
    this._closeSound();
    if (this._soundTimer !== null) {
      return;
    }
    this._soundTimer = window.setTimeout(() => {
      this._soundTimer = null;
      const { sound } = producersNow(this._api);
      if (sound !== null) this._connectSound(sound.id);
    }, reconnectDelayMs);
  }

  _connectPicture(producerId) {
    this.close();
    const session = this._api.createConsumerSession(producerId);
    if (session === null) {
      this.reconnect();
      return;
    }
    this._picture = session;

    session.addEventListener("error", (event) => {
      if (this._picture !== session) return;
      this._handlers.status(`error: ${event.message}`);
      this.reconnect();
    });
    session.addEventListener("closed", () => {
      if (this._picture !== session) return;
      this._handlers.status("the session closed");
      this.reconnect();
    });
    session.addEventListener("streamsChanged", () => {
      const streams = session.streams;
      if (this._picture === session && streams.length > 0) this._handlers.pictureStream(streams[0]);
    });
    session.addEventListener("stateChanged", () => {
      const peerConnection = session.rtcPeerConnection;
      if (this._picture === session && peerConnection !== null) this._handlers.pictureReady(peerConnection);
    });

    this._handlers.status("connecting to the TV…");
    session.connect();
  }

  _connectSound(producerId) {
    this._closeSound();
    const session = this._api.createConsumerSession(producerId);
    if (session === null) {
      this._soundReconnect();
      return;
    }
    this._sound = session;

    session.addEventListener("error", (event) => {
      if (this._sound !== session) return;
      this._handlers.problem(`the sound stopped: ${event.message}`);
      this._soundReconnect();
    });
    session.addEventListener("closed", () => {
      if (this._sound === session) this._soundReconnect();
    });
    session.addEventListener("streamsChanged", () => {
      const streams = session.streams;
      if (this._sound === session && streams.length > 0) this._handlers.soundStream(streams[0]);
    });
    session.addEventListener("stateChanged", () => {
      const peerConnection = session.rtcPeerConnection;
      if (this._sound === session && peerConnection !== null) this._handlers.soundReady(peerConnection);
    });

    session.connect();
  }
}
