/*
 * The marker's numbers as one batch of measurements (M15 fix8): the page's
 * aggregates under the names the host's stream record carries into the
 * session's summary JSON — stages, gauges, counters and facts, the four
 * containers `stats/stream` takes — so the next phase's Dart can read them
 * without the page or the host learning a new body shape. The names are listed
 * in docs/streaming-marker.md and in the fix8 phase 3 report.
 *
 * Pure: one reader summary and the clock state in, one batch's items out.
 */

import { medianOf, percentileOf } from "./metrics.js";

/** The names every number is sent under, so a report and a test share one list. */
export const markerNames = {
  glass: "marker_glass",
  glassP95: "marker_glass_p95",
  press: "press_to_marker",
  offset: "markerOffsetMs",
  offsetRtt: "markerOffsetRttMs",
  offsetUncertainty: "markerOffsetUncertaintyMs",
  callbackLate: "markerCallbackLateMs",
  decodedDisplay: "markerDecodeDisplayMs",
  read: "markerReadMs",
  frames: "markerFrames",
  readable: "markerReadable",
  checksumBad: "markerChecksumBad",
  syncBad: "markerSyncBad",
  canvasBad: "markerCanvasBad",
  otherBad: "markerOtherBad",
  displayFrom: "markerDisplayFrom",
  rawField: "rvfc.",
};

/**
 * The unit each raw metadata field is written in, as "min median max" in one
 * fact, and why: seconds with two decimals for a timestamp (the longest this
 * may grow is a run of hours), milliseconds to a tenth for a duration, whole
 * pixels and frames for a size, and 90 kHz ticks relative to the batch's
 * smallest for an RTP timestamp, whose absolute value is a random base.
 */
const rawUnits = {
  presentationTime: { scale: 1 / 1000, decimals: 2 },
  expectedDisplayTime: { scale: 1 / 1000, decimals: 2 },
  captureTime: { scale: 1 / 1000, decimals: 2 },
  receiveTime: { scale: 1 / 1000, decimals: 2 },
  processingDuration: { scale: 1000, decimals: 1 },
  presentedFrames: { scale: 1, decimals: 0 },
  width: { scale: 1, decimals: 0 },
  height: { scale: 1, decimals: 0 },
  mediaTime: { scale: 1, decimals: 2 },
  rtpTimestamp: { scale: 1, decimals: 0, relative: true },
};

/**
 * One batch's marker items: the stages, gauges, counters and facts the
 * reporter appends to its own.
 * @param {object} summary - the reader's `summary()`
 * @param {{offsetMs: number, rttMs: number, uncertaintyMs: number}|null} clock
 * @returns {{stages: object[], gauges: object[], counters: object[], facts: object[]}}
 */
export function markerBatch(summary, clock) {
  const stages = [];
  const gauges = [];
  const counters = [];
  const facts = [];
  const glassMedianMs = medianOf(summary.glassMs);
  const glassP95Ms = percentileOf(summary.glassMs, 0.95);
  if (glassMedianMs !== null) stages.push({ name: markerNames.glass, ms: Math.round(glassMedianMs) });
  if (glassP95Ms !== null) stages.push({ name: markerNames.glassP95, ms: Math.round(glassP95Ms) });
  for (const ms of summary.pressesMs) stages.push({ name: markerNames.press, ms });
  if (clock !== null && clock !== undefined) {
    gauges.push({ name: markerNames.offset, value: round2(clock.offsetMs) });
    gauges.push({ name: markerNames.offsetRtt, value: round2(clock.rttMs) });
    gauges.push({ name: markerNames.offsetUncertainty, value: round2(clock.uncertaintyMs) });
  }
  const callbackLateMs = medianOf(summary.callbackLateMs);
  if (callbackLateMs !== null) gauges.push({ name: markerNames.callbackLate, value: round2(callbackLateMs) });
  const decodedDisplayMs = medianOf(summary.decodedDisplayMs);
  if (summary.displayFrom !== "" && decodedDisplayMs !== null) {
    gauges.push({ name: markerNames.decodedDisplay, value: round2(decodedDisplayMs) });
    facts.push({ name: markerNames.displayFrom, value: summary.displayFrom });
  }
  if (summary.readMs.length > 0) gauges.push({ name: markerNames.read, value: round2(mean(summary.readMs)) });
  counters.push({ name: markerNames.frames, value: summary.frames });
  counters.push({ name: markerNames.readable, value: summary.readable });
  counters.push({ name: markerNames.checksumBad, value: summary.reasons.checksum ?? 0 });
  counters.push({ name: markerNames.syncBad, value: summary.reasons.sync ?? 0 });
  counters.push({ name: markerNames.canvasBad, value: summary.reasons.canvas ?? 0 });
  const otherBad = (summary.reasons.level ?? 0) + (summary.reasons.border ?? 0) + (summary.reasons.crop ?? 0);
  counters.push({ name: markerNames.otherBad, value: otherBad });
  for (const [field, samples] of Object.entries(summary.raw)) {
    const unit = rawUnits[field];
    if (unit === undefined || samples.length === 0) continue;
    facts.push({ name: `${markerNames.rawField}${field}`, value: tripleText(samples, unit) });
  }
  return { stages, gauges, counters, facts };
}

/**
 * One raw field's "min median max" as the fact's value: [unit]'s scale and
 * decimals, relative to the batch's smallest when the field's absolute value is
 * a base of no use (an RTP timestamp's).
 */
export function tripleText(samples, unit) {
  const base = unit.relative ? Math.min(...samples) : 0;
  const values = [Math.min(...samples), medianOf(samples), Math.max(...samples)];
  return values.map((value) => ((value - base) * unit.scale).toFixed(unit.decimals)).join(" ");
}

/** The mean of [values]. */
function mean(values) {
  return values.reduce((sum, value) => sum + value, 0) / values.length;
}

const round2 = (value) => Math.round(value * 100) / 100;
