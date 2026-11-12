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
