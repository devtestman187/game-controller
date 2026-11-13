/*
 * The player page's options (M15 fix7): the switches the page is asked to run
 * with, as `key=value` pairs. The session's environment
 * (SESSION_PLAYER_OPTIONS, which entrypoint.sh writes into config.js) gives the
 * defaults and the page's own URL query overrides them key by key, so a bench
 * run or one phone link turns a switch on without a rebuild. Nothing set means
 * the page behaves as it always did.
 */

// What a key with no `=value` part gets, the way an HTML attribute works.
const bareValue = "1";

// `search` is a page URL's query string, with or without its leading `?`;
// `defaults` is the config.js options object. The answer is a new object holding
// every default key and every query key — unknown keys included, because later
// jobs add keys — with the query's value wherever it has one. Pure: it reads
// nothing and changes neither argument.
export function parseOptions(search, defaults = {}) {
  const options = {};
  for (const [key, value] of Object.entries(defaults ?? {})) {
    if (key !== "") options[key] = String(value);
  }
  const query = String(search ?? "").replace(/^\?/, "");
  for (const part of query.split("&")) {
    if (part === "") continue;
    const at = part.indexOf("=");
    const key = at < 0 ? part : part.slice(0, at);
    if (key === "") continue;
    options[key] = at < 0 ? bareValue : part.slice(at + 1);
  }
  return options;
}

// The stats overlay's line for an options object, `a=1 b=x` with the keys in
// one order however the URL listed them, or "" when no key is set.
export function optionsLine(options) {
  const keys = Object.keys(options).sort();
  if (keys.length === 0) return "";
  return `options: ${keys.map((key) => `${key}=${options[key]}`).join(" ")}`;
}

// The values of a switch that mean on, as `lowdelay=1` reads them: a bare key
// becomes "1", and a person may write the word.
const onValues = ["1", "true", "on", "yes"];

// The two picture paths the page can play (M15 opt2): "wc" is the custom
// WebCodecs player, and everything else is the WebRTC player it has always had.
const wcKind = "wc";
const webrtcKind = "webrtc";

/**
 * Which picture path the page is asked to play (M15 opt2): "wc" only when the
 * `player` option is exactly "wc" (`?player=wc` or SESSION_PLAYER_OPTIONS), and
 * "webrtc" for every other value and for none at all, so a page that says
 * nothing plays exactly as it did.
 * @param {object|null|undefined} options
 * @returns {string} "wc" or "webrtc"
 */
export function playerKindOf(options) {
  const value = options === null || options === undefined ? "" : String(options.player ?? "");
  return value === wcKind ? wcKind : webrtcKind;
}

// Whether the page is asked to read the host's marker row out of the picture
// (M15 fix8): `marker=1` on the page's URL or in SESSION_PLAYER_OPTIONS. Off,
// no strip is read and none of its numbers is sent.
export function markerEnabled(options) {
  const value = options === null || options === undefined ? "" : String(options.marker ?? "");
  return onValues.includes(value.toLowerCase());
}
