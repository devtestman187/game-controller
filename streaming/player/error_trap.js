/*
 * The page's error trap (M15 opt2b): a page that throws, or whose promise
 * nobody caught, says so on the status line with the file and line, and sends
 * one small report to the relay, which writes it to the session's log. A phone
 * Safari that fails where a desktop Chrome does not otherwise leaves no trace.
 *
 * index.html loads this before the player, so a failure in any of its modules
 * is caught. The trap never throws itself, and one page load reports at most
 * [maxReports] errors.
 */

import { sessionIdOf } from "./page_state.js";

/** The most errors one page load shows and sends: a loop of them must not flood the log. */
export const maxReports = 5;

/** The most characters of a message or a place the report carries. */
const maxTextChars = 200;

/** The last part of a url, so the line names a file and not a whole address. */
function fileOf(url) {
  const text = String(url ?? "");
  const cut = text.lastIndexOf("/");
  return cut === -1 ? text : text.slice(cut + 1);
}

/**
 * Where a stack says it was thrown, as `file.js:12`, or "" when it says nothing:
 * a stack's first frame is the line the error came from.
 * @param {string} stack
 * @returns {string}
 */
function siteOf(stack) {
  const found = /([^/\\:()\s]+):(\d+):\d+/.exec(String(stack ?? ""));
  return found === null ? "" : `${found[1]}:${found[2]}`;
}

/** [text] cut to what one report carries. */
function shortOf(text) {
  return String(text ?? "").slice(0, maxTextChars);
}

/**
 * Sends one page error to the relay, which writes it to the session's log.
 * Nothing is awaited and nothing throws: a page that is already failing must
 * not fail again on the way out.
 * @param {{message: string, site: string}} error - what happened and where
 */
export async function sendPageError({ message, site }) {
  try {
    await fetch("/page/error", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ sessionId: sessionIdOf(), message: shortOf(message), site: shortOf(site) }),
    });
  } catch (error) {
    console.warn(`player: cannot send a page error: ${error.message}`);
  }
}

/**
 * Shows and sends every uncaught error and rejection from now on. Loaded
 * first by the page, this is what makes a browser-only failure visible.
 * @param {object} [parts]
 * @param {Window} [parts.target] - where the handlers are registered
 * @param {HTMLElement|null} [parts.statusLine] - the page's status line; the
 *   page's own `#status` element by default
 * @param {(text: string) => void} [parts.setTitle] - shows the same text in the
 *   tab's title, which a run can read off a page it left open
 * @param {(error: {message: string, site: string}) => void} [parts.send] - where
 *   a report goes
 * @returns {{report: (text: string, site?: string) => void, stop: () => void}}
 */
export function installErrorTrap({
  target = globalThis,
  statusLine = null,
  setTitle = (text) => {
    document.title = text;
  },
  send = sendPageError,
} = {}) {
  let reports = 0;

  const take = (message, site) => {
    // Nothing in here may throw: this runs while the page is already failing.
    try {
      if (reports >= maxReports) return;
      reports++;
      const text = `page error: ${shortOf(message)}${site === "" ? "" : ` (${site})`}`;
      const line = statusLine ?? document.getElementById("status");
      if (line !== null) line.textContent = text;
      setTitle(text);
      send({ message: shortOf(message), site });
    } catch (error) {
      console.warn(`player: the error trap itself failed: ${error.message}`);
    }
  };

  const onError = (event) => {
    const message = event?.message ?? event?.error?.message ?? "an error";
    const site = event?.filename ? `${fileOf(event.filename)}:${event.lineno ?? 0}` : siteOf(event?.error?.stack);
    take(message, site);
  };

  const onRejection = (event) => {
    const reason = event?.reason;
    take(reason?.message ?? String(reason ?? "a promise failed"), siteOf(reason?.stack));
  };

  target.addEventListener("error", onError);
  target.addEventListener("unhandledrejection", onRejection);
  return {
    report: (text, site = "") => take(text, site),
    stop: () => {
      target.removeEventListener("error", onError);
      target.removeEventListener("unhandledrejection", onRejection);
    },
  };
}
