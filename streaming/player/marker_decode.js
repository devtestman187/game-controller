/*
 * The player's marker decoder (M15 fix8): the pure half of reading the host's
 * marker row out of the picture. A crop of the row as luminances in, one
 * frame's counter, host clock and press flip out, or the reason the row cannot
 * be read — a guess is never a reading.
 *
 * Every rule here is docs/streaming-marker.md's, cell for cell, and the same
 * rule as the host's reference decoder (marker_decoder.dart) and its tests.
 */

/** The luminance below which a cell reads as dark, after its 3x3 centre mean. */
export const markerDarkBelow = 80;

/** The luminance above which a cell reads as light, after the same mean. */
export const markerLightAbove = 160;

/** The light border cells that frame the row at each end. */
const borderCells = 1;

/** The cells of the row's start mark: light, then dark. */
const syncCells = 2;

/** The bits of the frame counter, which wraps at [markerCounterWrap]. */
const counterBits = 16;

/** The bits of the host clock the row carries: its low 32. */
const hostMsBits = 32;

/** The cell that flips on the frame a probe press was applied in. */
const pressFlipCells = 1;

/** The bits of the checksum: the xor of the other cells' twelve nibbles. */
const checksumBits = 4;

/** The cells a frame's content fills, the borders aside: 55. */
const valueCells = syncCells + counterBits + hostMsBits + pressFlipCells + checksumBits;

/** Every cell of the row, the two border cells included: 57. */
export const markerCellCount = valueCells + 2 * borderCells;

/** The frame counter's wrap: a 16-bit count, so a long run reuses numbers. */
export const markerCounterWrap = 2 ** counterBits;

/** The clock's wrap: the row carries the low 32 bits of the host's clock. */
export const markerHostMsWrap = 2 ** hostMsBits;

/** The values one nibble of the checksum's xor covers. */
const nibbleValues = 2 ** checksumBits;

/**
 * Reads the marker out of [rows], the row's own crop of a picture: its rows of
 * luminance, 0 (dark) to 255 (light), the first row at the top. The crop is cut
 * into [markerCellCount] columns of equal width and each cell is read from the
 * mean of the 3x3 pixels at its centre, as the host's reference decoder does;
 * the crop's middle row is the one read, so a one-cell-tall or taller crop both
 * work.
 *
 * The answer is `{ok: true, counter, hostMs, pressFlip}` or
 * `{ok: false, kind, reason}`: [kind] is `crop`, `level`, `border`, `sync` or
 * `checksum`, so the page can count unreadable frames by reason.
 * @param {number[][]} rows - luminance, one array per row
 * @returns {{ok: true, counter: number, hostMs: number, pressFlip: boolean} |
 *   {ok: false, kind: string, reason: string}}
 */
export function decodeMarker(rows) {
  if (!Array.isArray(rows) || rows.length === 0 || rows[0] === undefined || rows[0].length === 0) {
    return unreadable("crop", "the crop is empty");
  }
  const widthPx = rows[0].length;
  if (widthPx < markerCellCount) {
    return unreadable("crop", `the crop is ${widthPx} px wide, too narrow for ${markerCellCount} cells`);
  }
  const cellPx = Math.floor(widthPx / markerCellCount);
  const centreY = Math.floor(rows.length / 2);
  const cells = [];
  for (let cell = 0; cell < markerCellCount; cell++) {
    const level = centreMean(rows, cell * cellPx + Math.floor(cellPx / 2), centreY);
    if (level < markerDarkBelow) {
      cells.push(false);
    } else if (level > markerLightAbove) {
      cells.push(true);
    } else {
      return unreadable("level", `the cell at ${cell} is neither dark nor light (${level})`);
    }
  }
  for (let border = 0; border < borderCells; border++) {
    if (!cells[border] || !cells[markerCellCount - 1 - border]) {
      return unreadable("border", `the border cell at ${border} is not light`);
    }
  }
  return decodeMarkerCells(cells.slice(borderCells, markerCellCount - borderCells));
}

/**
 * The frame [cells] carries, or why they cannot be one: a short or long row,
 * the wrong sync cells, or a checksum that does not match. [cells] are the
 * content cells only ([valueCells] of them), most significant first.
 * @param {boolean[]} cells
 * @returns {{ok: true, counter: number, hostMs: number, pressFlip: boolean} |
 *   {ok: false, kind: string, reason: string}}
 */
export function decodeMarkerCells(cells) {
  if (!Array.isArray(cells) || cells.length !== valueCells) {
    return unreadable("crop", `the row has ${cells?.length ?? 0} content cells, not ${valueCells}`);
  }
  if (!cells[0] || cells[1]) return unreadable("sync", "the sync cells are not light then dark");
  const counter = valueAt(cells, syncCells, counterBits);
  const hostMs = valueAt(cells, syncCells + counterBits, hostMsBits);
  const pressFlip = cells[syncCells + counterBits + hostMsBits];
  const checksum = valueAt(cells, syncCells + counterBits + hostMsBits + pressFlipCells, checksumBits);
  if (checksum !== markerChecksum({ counter, hostMs, pressFlip })) {
    return unreadable("checksum", "the checksum does not match");
  }
  return { ok: true, counter, hostMs, pressFlip };
}

/**
 * The checksum of one frame: the xor of every nibble of the counter and the
 * clock, with the press flip as the lowest bit of the lowest nibble.
 * @param {{counter: number, hostMs: number, pressFlip: boolean}} frame
 * @returns {number}
 */
export function markerChecksum({ counter, hostMs, pressFlip }) {
  let sum = pressFlip ? 1 : 0;
  // Arithmetic, not bit operators: a 48-bit value does not fit JavaScript's
  // 32-bit bitwise ones.
  let value = (counter % markerCounterWrap) * markerHostMsWrap + (hostMs % markerHostMsWrap);
  for (let nibble = 0; nibble < (counterBits + hostMsBits) / checksumBits; nibble++) {
    sum ^= value % nibbleValues;
    value = Math.floor(value / nibbleValues);
  }
  return sum;
}

/**
 * How long after the frame's stamp a host time lies, in ms: the row carries the
 * host clock's low 32 bits, so the difference is taken modulo that wrap and
 * read as a signed number.
 * @param {number} hostAtMs - a host time the page worked out, in ms
 * @param {number} markerHostMs - the row's low 32 bits of the host clock
 * @returns {number}
 */
export function markerGapMs(hostAtMs, markerHostMs) {
  const half = markerHostMsWrap / 2;
  let gap = (hostAtMs - markerHostMs) % markerHostMsWrap;
  if (gap < 0) gap += markerHostMsWrap;
  return gap > half ? gap - markerHostMsWrap : gap;
}

/** The mean luminance of the 3x3 pixels centred on [x], [y], over what the crop has. */
function centreMean(rows, x, y) {
  let sum = 0;
  let count = 0;
  for (let dy = -1; dy <= 1; dy++) {
    const row = rows[y + dy];
    if (row === undefined) continue;
    for (let dx = -1; dx <= 1; dx++) {
      const column = x + dx;
      if (column < 0 || column >= row.length) continue;
      sum += row[column];
      count++;
    }
  }
  return Math.round(sum / count);
}

/** The number [bits] cells of [cells] hold from [start], most significant first. */
function valueAt(cells, start, bits) {
  let value = 0;
  for (let i = 0; i < bits; i++) value = value * 2 + (cells[start + i] ? 1 : 0);
  return value;
}

/** One unreadable row's answer. */
function unreadable(kind, reason) {
  return { ok: false, kind, reason };
}
