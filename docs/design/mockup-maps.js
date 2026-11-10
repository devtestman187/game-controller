// Thumb Party's Arena maps (M14), for docs/design/party-mockups.html: the five maps of the Bumper
// Round (design: docs/design/party-night.md sections 7b and 10), each drawn once so the page can
// show it small on the waiting card and in play at 1280 × 720. A map is drawn in field units — a
// 16 × 9 field — and takes a box, centring its field in it; every part takes pixels and scales
// with the field unit, so one drawing serves both sizes. Red is the colour of everything that
// makes you drop a coin (a bumper, a cannonball, a crate, a top, the drain); a spring is a yellow
// coil under a green cap; a belt is a strip with arrows. The look's shared parts are in
// mockup-parts.js; star() and the coins and marbles on a map are the party page's.

const MAP_W = 16, MAP_H = 9;
function arenaBox(x, y, w, h) { // the 16 × 9 field, centred in the box a card or a frame gives it
  const u = Math.min(w / MAP_W, h / MAP_H);
  return { u, ox: x + (w - MAP_W * u) / 2, oy: y + (h - MAP_H * u) / 2 };
}
const at = (b, a, c) => [b.ox + a * b.u, b.oy + c * b.u]; // field units → pixels

// ---- The ground a map is drawn on
function field(x, y, w, h, color, o = {}) {
  const id = 'fl' + (++uid);
  defs.push(`<pattern id="${id}" width="36" height="36" patternUnits="userSpaceOnUse"><circle cx="18" cy="18" r="2.4" fill="${T.ink}" fill-opacity=".12"/></pattern>`);
  return `<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="${color}"/>` +
    (o.dots === false ? '' : `<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="url(#${id})"/>`);
}
function stripeFill(a, b, deg, size) { // diagonal warning stripes, sized in px so they scale with the field
  const id = 'st' + (++uid);
  defs.push(`<pattern id="${id}" width="${size}" height="${size}" patternUnits="userSpaceOnUse" patternTransform="rotate(${deg})"><rect width="${size}" height="${size}" fill="${a}"/><rect width="${size / 2}" height="${size}" fill="${b}"/></pattern>`);
  return `url(#${id})`;
}

// ---- The pieces (design 7b): red makes you drop a coin, a spring and a belt never do
// The Arena's hazard: a red round bumper, its rings scaled with its size so it reads as well on
// a small map card as in a round. Red always means a hazard (design 7b).
function hazard(cx, cy, r) {
  return toy('circle', cx - r, cy - r, r * 2, r * 2, C.bad, { ow: Math.max(1.5, r * .18), shadow: Math.max(2, r * .2), glint: false }) +
    `<circle cx="${cx}" cy="${cy}" r="${r * .58}" fill="none" stroke="#fff" stroke-width="${Math.max(1.5, r * .2)}"/>` +
    `<circle cx="${cx}" cy="${cy}" r="${r * .3}" fill="${dark(C.bad, .4)}" stroke="${T.ink}" stroke-width="${Math.max(1.2, r * .12)}"/>`;
}
// A spring (design 7b): a yellow coil under a green cap, seen from above, with two windings
// showing below the cap. Never red: red is a hazard's colour.
function spring(cx, cy, r) {
  const ow = Math.max(1.5, r * .18), cap = r * .84;
  let g = `<ellipse cx="${cx}" cy="${cy + r * .34}" rx="${r}" ry="${r * .62}" fill="${C.sun}" stroke="${T.ink}" stroke-width="${ow}"/>`;
  g += `<path d="M${cx - r * .6} ${cy + r * .76} q${r * .3} ${r * .16} ${r * .6} 0" fill="none" stroke="${T.ink}" stroke-width="${ow * .9}" stroke-linecap="round"/>`;
  g += `<path d="M${cx} ${cy + r * .82} q${r * .3} ${r * .1} ${r * .58} ${-r * .06}" fill="none" stroke="${T.ink}" stroke-width="${ow * .9}" stroke-linecap="round"/>`;
  g += toy('circle', cx - cap, cy - r * .14 - cap, cap * 2, cap * 2, C.good, { ow: ow, shadow: Math.max(2, r * .18), glint: false });
  return g;
}
// A belt (design 7b): a conveyor strip with arrows that carry a marble along; the arrows show
// the way with effects off too, and the direction is never colour alone (G5).
function belt(x, y, w, h, dir = 1) {
  let g = toy('rect', x, y, w, h, '#6E7C99', { glint: false, ow: Math.max(1.5, h * .12), shadow: h * .1 });
  const n = Math.max(2, Math.round(w / (h * 2.6)));
  for (let i = 0; i < n; i++) {
    const cx = x + h * .9 + i * ((w - h * 1.8) / Math.max(1, n - 1));
    g += `<path d="M${cx - h * .26 * dir} ${y + h * .26} L${cx + h * .06 * dir} ${y + h * .5} L${cx - h * .26 * dir} ${y + h * .74}" fill="none" stroke="#FFF6E3" stroke-width="${h * .16}" stroke-linecap="round" stroke-linejoin="round"/>`;
  }
  return g;
}
const beltAt = (cx, cy, len, th, deg, dir = 1) => // a belt at any angle, about its own centre
  `<g transform="rotate(${deg} ${cx} ${cy})">${belt(cx - len / 2, cy - th / 2, len, th, dir)}</g>`;
// The race's goal pad: only the Playroom has one now (design 7b keeps every other map a Bumper arena).
function goal(x, y, s) {
  const ow = Math.max(1.5, s * .07);
  return `<rect x="${x}" y="${y + s * .45}" width="${s}" height="${s * .6}" rx="${s * .12}" fill="${C.good}" stroke="${T.ink}" stroke-width="${ow}"/>` +
    `<line x1="${x + s * .24}" y1="${y}" x2="${x + s * .24}" y2="${y + s * .7}" stroke="${T.ink}" stroke-width="${ow}"/>` +
    `<path d="M${x + s * .24} ${y} l${s * .46} ${s * .14} l${-s * .46} ${s * .16}Z" fill="#fff" stroke="${T.ink}" stroke-width="${ow * .8}" stroke-linejoin="round"/>`;
}
// A post (design 7b): a round solid pillar — a castle's tower or a factory's column — seen from above.
function post(cx, cy, r, color = '#A8B4D6') {
  const ow = Math.max(1.5, r * .16);
  return toy('circle', cx - r, cy - r, r * 2, r * 2, color, { ow: ow, shadow: r * .16, glint: false }) +
    `<circle cx="${cx}" cy="${cy}" r="${r * .62}" fill="${light(color, .18)}" stroke="${T.ink}" stroke-width="${ow * .9}"/>` +
    `<circle cx="${cx - r * .22}" cy="${cy - r * .22}" r="${r * .18}" fill="#fff" fill-opacity=".55"/>`;
}
// A flipper (design 7b): a wall on a pivot that flicks up, drawn as a rounded bar from its hinge.
function flipper(px, py, len, deg) {
  const th = len * .34, ow = Math.max(1.5, th * .16);
  return `<g transform="rotate(${deg} ${px} ${py})">` +
    toy('rect', px, py - th / 2, len, th, T.wall, { glint: false, ow: ow, shadow: th * .18 }) +
    `<circle cx="${px}" cy="${py}" r="${th * .36}" fill="${T.paper}" stroke="${T.ink}" stroke-width="${ow * .8}"/>` +
    `<path d="M${px + len * .78} ${py} h${len * .14}" stroke="#fff" stroke-opacity=".8" stroke-width="${Math.max(1.2, th * .16)}" stroke-linecap="round"/></g>`;
}
// A gate (design 7b): a portcullis bar that slides aside along its track; open 0 shuts it across
// the gap, 1 slides it fully aside. The dashed track shows where it travels.
function gate(cx, cy, len, deg, open = 0) {
  const th = len * .34, ow = Math.max(1.5, th * .16), slide = (open - .5) * len * .8, bx = cx + slide - len * .3;
  let g = `<g transform="rotate(${deg} ${cx} ${cy})">`;
  g += `<line x1="${cx - len * .5}" y1="${cy}" x2="${cx + len * .5}" y2="${cy}" stroke="${T.ink}" stroke-opacity=".35" stroke-width="${Math.max(1.2, th * .12)}" stroke-dasharray="${th * .3} ${th * .24}"/>`;
  g += toy('rect', bx, cy - th / 2, len * .6, th, '#C9D2E8', { glint: false, ow: ow, shadow: th * .16 });
  for (let i = 1; i < 3; i++) g += `<path d="M${bx + (len * .6 * i) / 3} ${cy - th * .3} v${th * .6}" stroke="${T.ink}" stroke-width="${Math.max(1, th * .1)}" stroke-linecap="round"/>`;
  return g + '</g>';
}
// A cannonball (design 7b): a slide hazard, red-rimmed so it reads as one of the things that
// makes you drop a coin.
function cannonball(cx, cy, r) {
  const ow = Math.max(1.5, r * .16);
  return toy('circle', cx - r, cy - r, r * 2, r * 2, '#3A3550', { ow: ow, shadow: r * .2, glint: false }) +
    `<circle cx="${cx}" cy="${cy}" r="${r * .8}" fill="none" stroke="${C.bad}" stroke-width="${Math.max(1.5, r * .26)}"/>` +
    `<circle cx="${cx - r * .34}" cy="${cy - r * .38}" r="${r * .16}" fill="#fff" fill-opacity=".7"/>`;
}
// A crate (design 7b): a slide hazard in warning stripes — red and white, so it is never mistaken
// for scenery.
function crate(cx, cy, s) {
  const ow = Math.max(1.5, s * .14), x = cx - s, y = cy - s;
  let g = toy('rect', x, y, s * 2, s * 2, '#C08A4A', { ow: ow, shadow: s * .18, glint: false });
  g += `<rect x="${x + s * .28}" y="${y + s * .78}" width="${s * 1.44}" height="${s * .46}" fill="${stripeFill(C.bad, '#fff', 45, Math.max(3, s * .3))}" stroke="${T.ink}" stroke-width="${ow * .7}"/>`;
  g += `<path d="M${x + s * .26} ${y + s * .3} H${x + s * 1.74} M${x + s * .26} ${y + s * .55} H${x + s * 1.74}" stroke="${dark('#C08A4A', .3)}" stroke-width="${Math.max(1, s * .08)}"/>`;
  return g;
}
// A spinning top (design 7b): an orbiting hazard — a red cone with a white ring and its stem up —
// drawn so it reads as a top, not a bumper.
function spinningTop(cx, cy, r) {
  const ow = Math.max(1.5, r * .16);
  let g = `<ellipse cx="${cx + r * .1}" cy="${cy + r * .95}" rx="${r * .8}" ry="${r * .2}" fill="${T.ink}" fill-opacity=".16"/>`;
  g += `<path d="M${cx - r * .82} ${cy + r * .1} Q${cx} ${cy + r * 1.3} ${cx + r * .82} ${cy + r * .1} Z" fill="${C.bad}" stroke="${T.ink}" stroke-width="${ow}" stroke-linejoin="round"/>`;
  g += `<ellipse cx="${cx}" cy="${cy - r * .05}" rx="${r * .9}" ry="${r * .32}" fill="${light(C.bad, .2)}" stroke="${T.ink}" stroke-width="${ow}"/>`;
  g += `<ellipse cx="${cx}" cy="${cy - r * .05}" rx="${r * .52}" ry="${r * .17}" fill="none" stroke="#fff" stroke-width="${Math.max(1.2, r * .16)}"/>`;
  g += `<rect x="${cx - r * .1}" y="${cy - r * 1.15}" width="${r * .2}" height="${r * .6}" rx="${r * .1}" fill="${T.paper}" stroke="${T.ink}" stroke-width="${ow * .8}"/>`;
  g += `<circle cx="${cx}" cy="${cy - r * 1.2}" r="${r * .16}" fill="${T.paper}" stroke="${T.ink}" stroke-width="${ow * .7}"/>`;
  return g + `<path d="M${cx - r * 1.2} ${cy - r * .3} q${-r * .3} ${r * .3} ${-r * .05} ${r * .7} M${cx + r * 1.2} ${cy - r * .3} q${r * .3} ${r * .3} ${r * .05} ${r * .7}" fill="none" stroke="${T.ink}" stroke-opacity=".45" stroke-width="${Math.max(1, r * .1)}" stroke-linecap="round"/>`;
}

// ---- Scenery the maps paint themselves
function wallRect(b, a, c, w, h, color, o = {}) {
  return toy('rect', b.ox + a * b.u, b.oy + c * b.u, w * b.u, h * b.u, color,
    { glint: false, shadow: b.u * .1, ow: Math.max(1.5, b.u * .055), ...o });
}
function gear(cx, cy, r) { // painted on a factory floor: faint, with no outline of its own
  let g = `<circle cx="${cx}" cy="${cy}" r="${r * .72}" fill="${T.ink}" fill-opacity=".07"/>`;
  for (let i = 0; i < 8; i++) {
    const a = (i * Math.PI) / 4, x = cx + Math.cos(a) * r * .84, y = cy + Math.sin(a) * r * .84;
    g += `<rect x="${x - r * .15}" y="${y - r * .15}" width="${r * .3}" height="${r * .3}" rx="${r * .06}" fill="${T.ink}" fill-opacity=".07" transform="rotate(${i * 45} ${x} ${y})"/>`;
  }
  return g + `<circle cx="${cx}" cy="${cy}" r="${r * .3}" fill="${T.ink}" fill-opacity=".07"/><circle cx="${cx}" cy="${cy}" r="${r * .72}" fill="none" stroke="${T.ink}" stroke-opacity=".1" stroke-width="${Math.max(1.2, r * .06)}"/>`;
}
function pennant(px, py, s, color = C.good) { // a tower's flag, sized with the field so it reads on a card
  return `<line x1="${px}" y1="${py}" x2="${px}" y2="${py - s * 1.25}" stroke="${T.ink}" stroke-width="${Math.max(1.2, s * .16)}" stroke-linecap="round"/>` +
    `<path d="M${px} ${py - s * 1.25} l${s * .95} ${s * .3} l${-s * .95} ${s * .32}Z" fill="${color}" stroke="${T.ink}" stroke-width="${Math.max(1, s * .13)}" stroke-linejoin="round"/>`;
}
function chevron(cx, cy, s) { // the pinball table's painted lane arrows
  return `<path d="M${cx - s} ${cy + s * .55} L${cx} ${cy - s * .55} L${cx + s} ${cy + s * .55}" fill="none" stroke="#8FA0E8" stroke-width="${Math.max(1.2, s * .5)}" stroke-linecap="round" stroke-linejoin="round"/>`;
}
const track = (b, a, c, a2, u) => { // a hazard's travel, dashed
  const p = at(b, a, c), q = at(b, a2, c);
  return `<line x1="${p[0]}" y1="${p[1]}" x2="${q[0]}" y2="${q[1]}" stroke="${T.ink}" stroke-opacity=".28" stroke-width="${Math.max(1.2, u * .06)}" stroke-dasharray="${u * .2} ${u * .16}" stroke-linecap="round"/>`;
};

// ---- The five maps
function playroomMap(x, y, w, h, o = {}) { // today's field, the only map with a race
  const b = arenaBox(x, y, w, h);
  let g = field(x, y, w, h, T.field);
  [[3.7, .7, .37, 4.8], [7.4, 4.2, .37, 5], [11.1, .7, .37, 3.2], [11.1, 5.8, .37, 3.3], [4.7, 6.5, 1.8, .37]]
    .forEach(([a, c, ww, hh]) => g += wallRect(b, a, c, ww, hh, T.wall, { shadow: b.u * .14 }));
  [[5.6, 1.8], [9.3, 5.7], [11.8, 5.2], [5, 8]].forEach(([a, c]) => g += hazard(...at(b, a, c), b.u * .45));
  if (o.goal !== false) g += goal(...at(b, 13.4, 3.4), b.u * 1.5);
  return g;
}
function pinballMap(x, y, w, h) { // a toy pinball table, seen from above
  const b = arenaBox(x, y, w, h), u = b.u, P = (a, c) => at(b, a, c);
  const x0 = b.ox + 1.2 * u, x1 = b.ox + 14.8 * u, y0 = b.oy + .4 * u, y1 = b.oy + 8.6 * u, rt = 3.2 * u, rb = .8 * u;
  const table = `M${x0} ${y1 - rb} L${x0} ${y0 + rt} Q${x0} ${y0} ${x0 + rt} ${y0} L${x1 - rt} ${y0} Q${x1} ${y0} ${x1} ${y0 + rt} L${x1} ${y1 - rb} Q${x1} ${y1} ${x1 - rb} ${y1} L${x0 + rb} ${y1} Q${x0} ${y1} ${x0} ${y1 - rb}Z`;
  const clip = 'pb' + (++uid);
  defs.push(`<clipPath id="${clip}"><path d="${table}"/></clipPath>`);
  let g = field(x, y, w, h, '#2C2A66', { dots: false }) + `<path d="${table}" fill="#3E3A8C"/><g clip-path="url(#${clip})">`;
  for (let i = 0; i < 8; i++) {
    const a = x0 + (i * (x1 - x0)) / 8, z = x0 + ((i + 1) * (x1 - x0)) / 8;
    g += `<path d="M${a} ${y0} L${z} ${y0} L${x0 + ((i + .5) * (x1 - x0)) / 8} ${y1} L${x0 + ((i - .5) * (x1 - x0)) / 8} ${y1}Z" fill="#5B55C4" fill-opacity=".45"/>`;
  }
  g += `</g><path d="${table}" fill="none" stroke="${T.ink}" stroke-width="${Math.max(2, u * .09)}"/>`;
  [1.9, 13.7].forEach(a => { const p = P(a, 2.4); g += toy('rect', p[0], p[1], .4 * u, 5.4 * u, '#C9D2E8', { glint: false, shadow: u * .08, ow: Math.max(1.5, u * .05) }); });
  [[3.2, 2.4], [12.8, 2.4], [2.9, 7.3], [13.1, 7.3]].forEach(([a, c]) => { const p = P(a, c); g += star(p[0], p[1], u * .24, '#8FA0E8', { ow: Math.max(1.2, u * .05) }); });
  [[3.6, 5], [3.6, 6.4], [12.4, 5], [12.4, 6.4]].forEach(([a, c]) => { const p = P(a, c); g += chevron(p[0], p[1], u * .3); });
  [[5.9, 1.5], [7.5, 1.5], [9.1, 1.5], [10.7, 1.5]].forEach(([a, c]) => { const p = P(a, c); g += post(p[0], p[1], u * .26, '#C9D2E8'); });
  [6.7, 8.3, 9.9].forEach(a => { const p = P(a, 2.4); g += chevron(p[0], p[1], u * .28); });
  [[8, 3.1], [6.7, 4.1], [9.3, 4.1]].forEach(([a, c]) => { const p = P(a, c); g += spring(p[0], p[1], u * .42); });
  const sling = (a, c, deg) => { const p = P(a, c), len = 2 * u;
    return `<g transform="rotate(${deg} ${p[0]} ${p[1]})">` + toy('rect', p[0] - len / 2, p[1] - u * .18, len, u * .36, T.wall, { glint: false, ow: Math.max(1.5, u * .05), shadow: u * .1 }) + '</g>'; };
  g += sling(4.9, 6.9, -35) + sling(11.1, 6.9, 35);
  const fl = P(6.4, 7.7), fr = P(9.6, 7.7), dr = P(8, 8.3);
  g += flipper(fl[0], fl[1], u * 1.5, 18) + flipper(fr[0], fr[1], u * 1.5, 162);
  g += `<rect x="${dr[0] - .5 * u}" y="${dr[1] - .3 * u}" width="${u}" height="${.6 * u}" rx="${.2 * u}" fill="${T.ink}" fill-opacity=".5"/>` + hazard(dr[0], dr[1], u * .24);
  return g;
}
function castleMap(x, y, w, h) { // a castle of toy blocks: walls, towers, a lawn and a keep
  const b = arenaBox(x, y, w, h), u = b.u, P = (a, c) => at(b, a, c), stone = '#A8B4D6', stoneD = dark(stone, .16);
  let g = field(x, y, w, h, '#D6DCEA', { dots: false });
  g += `<rect x="${b.ox + 1.3 * u}" y="${b.oy + 1.3 * u}" width="${13.4 * u}" height="${6.4 * u}" rx="${.7 * u}" fill="#BFE3C8" stroke="${T.ink}" stroke-width="${Math.max(1.5, u * .06)}"/>`;
  [[1.3, 1.3, 13.4, .75], [1.3, 6.95, 13.4, .75], [1.3, 1.3, .75, 6.4], [13.95, 1.3, .75, 6.4]]
    .forEach(([a, c, ww, hh]) => g += wallRect(b, a, c, ww, hh, stone));
  for (let i = 0; i < 9; i++) {
    const a = 2.1 + i * 1.4;
    g += wallRect(b, a, 2.05, .55, .45, i % 2 ? stoneD : stone) + wallRect(b, a, 6.5, .55, .45, i % 2 ? stone : stoneD);
  }
  for (let i = 0; i < 3; i++) {
    const c = 2.7 + i * 1.45;
    g += wallRect(b, 2.05, c, .45, .55, i % 2 ? stoneD : stone) + wallRect(b, 13.5, c, .45, .55, i % 2 ? stone : stoneD);
  }
  [[1.9, 1.9], [14.1, 1.9], [1.9, 7.1], [14.1, 7.1]].forEach(([a, c]) => {
    const p = P(a, c);
    g += post(p[0], p[1], u * .72, '#C9D2E8') + pennant(p[0] + u * .1, p[1] - u * .95, u * .42);
  });
  [[5.6, 3, 1.85, .5], [8.55, 3, 1.85, .5], [5.6, 5.5, 1.85, .5], [8.55, 5.5, 1.85, .5],
    [5.6, 3.5, .5, .45], [5.6, 5.05, .5, .45], [9.9, 3.5, .5, .45], [9.9, 5.05, .5, .45]]
    .forEach(([a, c, ww, hh]) => g += wallRect(b, a, c, ww, hh, stoneD, { shadow: u * .06 }));
  const gt = P(8, 3.25), gb = P(8, 5.75), gl = P(5.85, 4.5), gr = P(10.15, 4.5);
  g += gate(gt[0], gt[1], u * 1.1, 0, .55) + gate(gb[0], gb[1], u * 1.1, 0, .2) +
    gate(gl[0], gl[1], u * 1.1, 90, .8) + gate(gr[0], gr[1], u * 1.1, 90, .35);
  [[3.3, 4.6, 2.2, 5.2], [12.7, 2.5, 11.6, 13.8], [11.4, 6.4, 10.4, 12.4]].forEach(([a, c, t0, t1]) => {
    const p = P(a, c);
    g += track(b, t0, c, t1, u) + cannonball(p[0], p[1], u * .32);
  });
  return g;
}
function factoryMap(x, y, w, h) { // a workshop floor: belts, a press, crates and columns
  const b = arenaBox(x, y, w, h), u = b.u, P = (a, c) => at(b, a, c);
  let g = field(x, y, w, h, '#B7C2D4', { dots: false });
  const bx = b.ox + .45 * u, by = b.oy + .45 * u, bw = 15.1 * u, bh = 8.1 * u, ew = .5 * u;
  g += `<rect x="${bx}" y="${by}" width="${bw}" height="${bh}" rx="${.4 * u}" fill="none" stroke="${stripeFill(C.sun, T.ink, 45, Math.max(4, u * .5))}" stroke-width="${ew}"/>` +
    `<rect x="${bx}" y="${by}" width="${bw}" height="${bh}" rx="${.4 * u}" fill="none" stroke="${T.ink}" stroke-width="${Math.max(1.2, u * .05)}"/>` +
    `<rect x="${bx + ew}" y="${by + ew}" width="${bw - 2 * ew}" height="${bh - 2 * ew}" rx="${.3 * u}" fill="none" stroke="${T.ink}" stroke-width="${Math.max(1.2, u * .05)}"/>`;
  [[3.6, 2.3, .85], [13.5, 2.4, .8], [12.9, 7, .85]].forEach(([a, c, s]) => { const p = P(a, c); g += gear(p[0], p[1], s * u); });
  const t = P(6.2, 2.8), bo = P(6.2, 6.4), lf = P(2.8, 4.6), ri = P(9.6, 4.6);
  g += beltAt(t[0], t[1], 6.8 * u, .8 * u, 0, 1) + beltAt(bo[0], bo[1], 6.8 * u, .8 * u, 0, -1) +
    beltAt(lf[0], lf[1], 3.6 * u, .8 * u, 90, -1) + beltAt(ri[0], ri[1], 3.6 * u, .8 * u, 90, 1);
  const pr = P(12.4, 4.6);
  [11, 13.8].forEach(a => { const p = P(a, 3.3); g += toy('rect', p[0] - .2 * u, p[1], .4 * u, 3.2 * u, T.wall, { glint: false, shadow: u * .08, ow: Math.max(1.5, u * .05) }); });
  g += toy('rect', pr[0] - u, pr[1] - .6 * u, 2 * u, 1.2 * u, '#6E7C99', { glint: false, shadow: u * .12, ow: Math.max(1.5, u * .06) })
    + `<path d="M${pr[0]} ${pr[1] - 1.9 * u} v${.85 * u} M${pr[0] - .28 * u} ${pr[1] - 1.35 * u} l${.28 * u} ${.3 * u} l${.28 * u} ${-.3 * u} M${pr[0]} ${pr[1] + 1.9 * u} v${-.85 * u} M${pr[0] - .28 * u} ${pr[1] + 1.35 * u} l${.28 * u} ${-.3 * u} l${.28 * u} ${.3 * u}" fill="none" stroke="${T.ink}" stroke-opacity=".5" stroke-width="${Math.max(1.2, u * .06)}" stroke-linecap="round" stroke-linejoin="round"/>`;
  [[5.2, 4.6, 4.4, 6], [11.8, 1.8, 11, 12.6]].forEach(([a, c, t0, t1]) => {
    const p = P(a, c);
    g += track(b, t0, c, t1, u) + crate(p[0], p[1], u * .6);
  });
  [[2, 1.7], [14, 1.7], [2, 7.3], [14, 7.3]].forEach(([a, c]) => { const p = P(a, c); g += post(p[0], p[1], u * .42, '#C9D2E8'); });
  return g;
}
function topsMap(x, y, w, h) { // a round rug with a ring of tops and a carousel in the middle
  const b = arenaBox(x, y, w, h), u = b.u, c0 = at(b, 8, 4.5), R = 4.15 * u, ring = R * .62;
  let g = field(x, y, w, h, '#DCE8D2', { dots: false });
  g += `<circle cx="${c0[0]}" cy="${c0[1]}" r="${R}" fill="#D9C6A6" stroke="${T.ink}" stroke-width="${Math.max(2, u * .07)}"/>`;
  [.84, .64, .42].forEach(k => g += `<circle cx="${c0[0]}" cy="${c0[1]}" r="${R * k}" fill="none" stroke="${dark('#D9C6A6', .16)}" stroke-width="${Math.max(1.2, u * .05)}"/>`);
  g += `<circle cx="${c0[0]}" cy="${c0[1]}" r="${ring}" fill="none" stroke="${T.ink}" stroke-opacity=".28" stroke-width="${Math.max(1.2, u * .05)}" stroke-dasharray="${u * .3} ${u * .24}"/>`;
  for (let i = 0; i < 8; i++) {
    const a = (i * Math.PI) / 4 + .25, tx = c0[0] + Math.cos(a) * ring, ty = c0[1] + Math.sin(a) * ring;
    g += spinningTop(tx, ty, u * .38) + `<line x1="${tx}" y1="${ty}" x2="${tx + Math.cos(a + Math.PI / 2) * u * .5}" y2="${ty + Math.sin(a + Math.PI / 2) * u * .5}" stroke="${T.ink}" stroke-opacity=".3" stroke-width="${Math.max(1.2, u * .05)}" stroke-linecap="round"/>`;
  }
  const arms = [0, 90, 180, 270].map(deg => `<g transform="rotate(${deg} ${c0[0]} ${c0[1]})">` +
    toy('rect', c0[0] + .9 * u, c0[1] - .26 * u, 1.6 * u, .52 * u, T.wall, { glint: false, ow: Math.max(1.5, u * .05), shadow: u * .1 }) + '</g>').join('');
  g += `<g transform="rotate(15 ${c0[0]} ${c0[1]})">${arms}</g>` + post(c0[0], c0[1], u * .52, '#C9D2E8');
  return g;
}

// Each map, and where a round's marbles and coins stand on it (field units; a marble is
// [x, y, player, coins], a coin [x, y, {spin, gold, sparkling}]).
const MAPS = {
  playroom: { name: 'Playroom', draw: playroomMap },
  pinball: { name: 'Pinball', draw: pinballMap, spots: {
    marbles: [[5.8, 5.5, 1, 4], [9.9, 6.5, 2, 2], [8.1, 4.9, 3, 1]],
    coins: [[6.7, 1.5, { spin: .12 }], [8.3, 1.5, { gold: true }], [9.9, 1.5, { spin: .62, sparkling: true }],
      [3.1, 5.4, { spin: .38 }], [12.9, 4.4, { spin: .8 }]] } },
  castle: { name: 'Block Castle', draw: castleMap, spots: {
    marbles: [[3.6, 2.7, 1, 3], [12.4, 5.6, 2, 5], [7.2, 6.6, 3, 0], [11.6, 1.9, 4, 2]],
    coins: [[3, 6.2, { spin: .2 }], [13.2, 2.3, { spin: .5, sparkling: true }], [7.2, 4.5, { gold: true }], [8.8, 4.5, { gold: true }]] } },
  factory: { name: 'Toy Factory', draw: factoryMap, spots: {
    marbles: [[7, 1.6, 1, 2], [9, 7.6, 2, 3], [11.8, 5.8, 3, 1]],
    coins: [[4, 4.6, { spin: .15 }], [8.6, 1.6, { gold: true }], [6, 7.5, { spin: .65 }], [10.6, 4.6, { spin: .4, sparkling: true }]] } },
  tops: { name: 'Spinning Tops', draw: topsMap, spots: {
    marbles: [[10.3, 6.8, 1, 3], [5.7, 6.8, 2, 1], [10.3, 2.2, 3, 0]],
    coins: [[8.8, 5.9, { spin: .25 }], [6.6, 5.3, { spin: .55 }], [7.2, 3.1, { spin: .8 }], [9.4, 3.7, { gold: true }]] } },
};
