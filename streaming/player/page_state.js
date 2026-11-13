/*
 * What the page tells the session's web server (M15 c2, fix7): a benchmark
 * reads it to know the page is playing instead of guessing, and a run reads
 * the stream ids in it to see whether the sound arrived on a stream of its own
 * (`SESSION_AUDIO=separate`).
 */

// Everything the page has said so far. Each report carries the whole of it, so
// a later one adds to what an earlier one said instead of losing it, and a run
// reads the last body.
const reported = {};

// Who is reporting: this page's own name and the session whose page it loaded,
// carried in every report (M15 fix8).
let identity = {};

// What the page does when the relay says it belongs to an earlier session.
let onStale = () => {};

/**
 * Sets what every report says about this page: its own id and the session it
 * was served by. A page left open from an earlier session keeps that session's
 * id, which is how the next session's relay tells it apart (M15 fix8).
 * @param {object} parts
 * @param {string} parts.pageId - this page's id, one per load
 * @param {string} parts.sessionId - the session whose page this is
 */
export function identifyPlayer({ pageId, sessionId }) {
  identity = { pageId, sessionId };
}

/**
 * Sets the one action a report from an earlier session causes: the page ends,
 * as it does when its own session ends (M15 fix8).
 * @param {() => void} handler
 */
export function setStaleHandler(handler) {
  onStale = handler;
}

/**
 * The session this page was served by, for the measurements' identity.
 * @returns {string}
 */
export function sessionIdOf() {
  return identity.sessionId ?? "";
}

/**
 * Sends the page's state, and whatever else the page knows with it, to the
 * relay this page came from.
 * @param {string} state - "streaming", "playing", "reconnecting", "closed", "ended"
 * @param {object} [extra] - more facts for the body, such as the stream ids
 */
export function reportPlayerState(state, extra = {}) {
  Object.assign(reported, identity, { state, ...extra });
  fetch("/player", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(reported),
  })
    .then((response) => response.json())
    .then((body) => {
      // A relay of the next session says `stale` to a page it did not serve.
      if (body !== null && body.stale === true) onStale();
    })
    .catch(() => {});
}

/**
 * The stream ids a connection's SDP names. A browser keeps one jitter buffer
 * and one sync group per id, so this list is what says whether the sound has a
 * stream id of its own.
 * webrtcbin names them the old way, on each source (`a=ssrc:… msid:…`), and a
 * browser's own SDP the new way (`a=msid:`), so both lines are read. `-` is
 * the placeholder for "no id" and is not an id.
 * @param {RTCPeerConnection|null} peerConnection
 * @returns {string[]}
 */
export function msidsOf(peerConnection) {
  const sdp = (peerConnection === null ? null : peerConnection.remoteDescription?.sdp) ?? "";
  const ids = [];
  for (const line of sdp.split("\n")) {
    if (line.startsWith("a=msid:")) ids.push(line.slice("a=msid:".length).split(" ")[0]);
    // `a=ssrc:<ssrc> msid:<id> <track>`: the id starts after " msid:".
    if (line.includes(" msid:")) ids.push(line.split(" msid:")[1].split(" ")[0]);
  }
  return [...new Set(ids.filter((id) => id !== "" && id !== "-"))];
}

/**
 * The ids a connection's SDP names, as one field of a report: a run reads them
 * to see whether the sound arrived on a stream of its own. A connection that
 * has not answered yet names none, so nothing is reported and a later report
 * keeps whatever an earlier one found.
 * @param {string} key - the field's name in the report ("msids", "soundMsids")
 * @param {RTCPeerConnection|null} peerConnection
 * @returns {object}
 */
export function msidFacts(key, peerConnection) {
  const ids = msidsOf(peerConnection);
  return ids.length === 0 ? {} : { [key]: ids };
}

/**
 * What the page is playing: "own" when the sound came on its own connection,
 * "joined" when it is the picture's own track, and "none" for a session that
 * sends no sound (`SESSION_AUDIO=off`).
 * @param {boolean} hasSoundStream - the sound connection delivered a stream
 * @param {boolean} hasPictureAudio - the picture's own stream carries sound
 * @returns {string}
 */
export function audioMode(hasSoundStream, hasPictureAudio) {
  if (hasSoundStream) return "own";
  return hasPictureAudio ? "joined" : "none";
}
