// Thumb Party's mock-up parts (M13), shared by docs/design/look-mockups.html and
// docs/design/party-mockups.html (M14): the palettes, the colours and every drawing
// helper of the "Toy Box Toon" look (docs/design/look-and-sound.md), so both pages
// draw one look from one place. A page pushes its frames into F and calls startPage(F).

const PAL = {
  sunny: { name: 'Sunny', ink: '#1E1646', bg: '#7CC8F8', glow: '#C4EAFF', dots: '#FFFFFF', dotsA: .28, onBg: '#1E1646',
    paper: '#FFF6E3', board: '#FFEFD0', tray: '#F5D9A8', neutral: '#B3A285', wall: '#7F8FD1', field: '#A9DCFB' },
  night: { name: 'Night', ink: '#120D2E', bg: '#241C5E', glow: '#3B2F8F', dots: '#FFFFFF', dotsA: .07, onBg: '#FFFFFF',
    paper: '#FFF6E3', board: '#30297A', tray: '#3D3592', neutral: '#9289D6', wall: '#8C9BD8', field: '#2A2270' },
};
const C = { focus: '#FFD23F', good: '#2FCB74', caution: '#FFB020', bad: '#FF4D5E',
  p: ['#2E9BF0', '#FF8A1F', '#9B5CFF', '#14C8A0', '#FF5C8A', '#F2C200'],
  face: { A: '#2FCB74', B: '#FF4D5E', X: '#2E9BF0', Y: '#FFD23F' },
  crown: '#2FCB74', trunk: '#C26A2C', sun: '#FFD23F', hill: '#8E9CC9', roof: '#FF5C8A' };
let T = PAL.sunny, FX = true, uid = 0, defs = [];

// ---- colour helpers
const hx = h => [1, 3, 5].map(i => parseInt(h.slice(i, i + 2), 16));
const toHex = a => '#' + a.map(v => Math.round(Math.max(0, Math.min(255, v))).toString(16).padStart(2, '0')).join('');
const mix = (h, to, t) => { const a = hx(h), b = hx(to); return toHex(a.map((v, i) => v + (b[i] - v) * t)); };
const light = (h, t = .38) => mix(h, '#FFFFFF', t), dark = (h, t = .26) => mix(h, '#000000', t);

// ---- primitives
function geo(kind, x, y, w, h, a = '') {
  if (kind === 'circle') return `<ellipse cx="${x + w / 2}" cy="${y + h / 2}" rx="${w / 2}" ry="${h / 2}" ${a}/>`;
  if (kind === 'tri') return `<polygon points="${x + w / 2},${y} ${x + w},${y + h} ${x},${y + h}" ${a}/>`;
  if (kind === 'pill') return `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${Math.min(w, h) / 2}" ${a}/>`;
  if (kind === 'house') return `<polygon points="${x},${y + h * .42} ${x + w / 2},${y} ${x + w},${y + h * .42}" ${a}/>`;
  const r = Math.min(w, h) * .14;
  return `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${r}" ${a}/>`;
}
function fillFor(color) {
  const id = 'g' + (++uid), hi = light(color), sh = dark(color);
  if (FX) defs.push(`<radialGradient id="${id}" cx="34%" cy="28%" r="80%" fx="30%" fy="24%">
    <stop offset="0" stop-color="${light(color, .55)}"/><stop offset=".22" stop-color="${hi}"/>
    <stop offset=".22" stop-color="${color}"/><stop offset=".66" stop-color="${color}"/>
    <stop offset=".66" stop-color="${sh}"/><stop offset=".9" stop-color="${dark(color, .34)}"/><stop offset="1" stop-color="${mix(sh, '#FFFFFF', .18)}"/></radialGradient>`);
  else defs.push(`<linearGradient id="${id}" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="${hi}"/><stop offset=".3" stop-color="${hi}"/><stop offset=".3" stop-color="${color}"/>
    <stop offset=".75" stop-color="${color}"/><stop offset=".75" stop-color="${sh}"/><stop offset="1" stop-color="${sh}"/></linearGradient>`);
  return `url(#${id})`;
}
// The one call that draws a game object: shadow, body, glint, ink outline.
function toy(kind, x, y, w, h, color, o = {}) {
  const ow = o.ow ?? 3, s = o.shadow ?? Math.max(3, Math.min(w, h) * .07);
  let g = '';
  if (s) g += geo(kind, x + s * .75, y + s, w, h, `fill="${T.ink}" fill-opacity=".35"`);
  g += geo(kind, x, y, w, h, `fill="${o.flat ? color : fillFor(color)}"`);
  if (o.glint !== false && w > 16) {
    const gx = kind === 'tri' ? x + w * .5 : x + w * .27, gy = kind === 'tri' ? y + h * .42 : y + h * .24;
    g += `<ellipse cx="${gx}" cy="${gy}" rx="${Math.max(2, w * .08)}" ry="${Math.max(1.5, h * .05)}" fill="#fff" fill-opacity="${FX ? .9 : .75}" transform="rotate(-30 ${gx} ${gy})"/>`;
  }
  g += geo(kind, x, y, w, h, `fill="none" stroke="${T.ink}" stroke-width="${ow}" stroke-linejoin="round"`);
  return g;
}
function target(kind, x, y, w, h, color) {
  return geo(kind, x, y, w, h, `fill="${color}" fill-opacity=".18" stroke="${color}" stroke-width="3.5" stroke-dasharray="9 6" stroke-linejoin="round" stroke-linecap="round"`);
}
function txt(x, y, s, size, o = {}) {
  const f = o.font ?? 'Fredoka', w = o.w ?? (f === 'Fredoka' ? 600 : 700), fill = o.fill ?? T.ink;
  const st = o.stroke ? `stroke="${o.stroke}" stroke-width="${o.sw ?? size * .16}" paint-order="stroke" stroke-linejoin="round"` : '';
  return `<text x="${x}" y="${y}" font-family="${f}, Nunito, sans-serif" font-weight="${w}" font-size="${size}" fill="${fill}" text-anchor="${o.anchor ?? 'start'}" dominant-baseline="${o.base ?? 'auto'}" ${st} ${o.extra ?? ''}>${s}</text>`;
}
function bg(w, h, o = {}) {
  const id = 'p' + (++uid), gl = 'r' + uid;
  defs.push(`<pattern id="${id}" width="44" height="44" patternUnits="userSpaceOnUse" patternTransform="rotate(${FX ? 18 : 0})">
    <circle cx="11" cy="11" r="${FX ? 5 : 4}" fill="${T.dots}" fill-opacity="${T.dotsA}"/><circle cx="33" cy="33" r="${FX ? 3 : 4}" fill="${T.dots}" fill-opacity="${T.dotsA * .8}"/></pattern>
    <radialGradient id="${gl}" cx="50%" cy="42%" r="70%"><stop offset="0" stop-color="${T.glow}"/><stop offset="1" stop-color="${T.bg}"/></radialGradient>`);
  return `<rect width="${w}" height="${h}" fill="url(#${gl})"/>` + (o.dots === false ? '' : `<rect width="${w}" height="${h}" fill="url(#${id})"/>`);
}
function card(x, y, w, h, o = {}) {
  const id = 'c' + (++uid);
  defs.push(`<clipPath id="${id}"><rect x="${x}" y="${y}" width="${w}" height="${h}" rx="18"/></clipPath>`);
  let g = `<rect x="${x + 4}" y="${y + 6}" width="${w}" height="${h}" rx="18" fill="${T.ink}" fill-opacity=".35"/>`;
  g += `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="18" fill="${o.fill ?? T.paper}"/>`;
  if (o.header) {
    const hh = o.hh ?? 54;
    g += `<g clip-path="url(#${id})"><rect x="${x}" y="${y}" width="${w}" height="${hh}" fill="${o.hc}"/><rect x="${x}" y="${y}" width="${w}" height="${hh * .45}" fill="#fff" fill-opacity=".22"/></g>`;
    g += `<line x1="${x}" y1="${y + hh}" x2="${x + w}" y2="${y + hh}" stroke="${T.ink}" stroke-width="3"/>`;
    g += txt(x + w / 2, y + hh / 2 + 2, o.header, o.hs ?? 26, { anchor: 'middle', base: 'middle' });
  }
  g += `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="18" fill="none" stroke="${T.ink}" stroke-width="${o.ow ?? 3.5}"/>`;
  return g;
}
function focusRing(x, y, w, h, r) {
  return `<rect x="${x - 9}" y="${y - 9}" width="${w + 18}" height="${h + 18}" rx="${r + 9}" fill="none" stroke="${T.ink}" stroke-width="10"/>
    <rect x="${x - 9}" y="${y - 9}" width="${w + 18}" height="${h + 18}" rx="${r + 9}" fill="none" stroke="${C.focus}" stroke-width="6"/>`;
}
function btn(x, y, w, h, label, o = {}) {
  const color = o.color ?? T.paper, st = o.state ?? 'normal', r = h / 2, s = st === 'pressed' ? 0 : 5;
  const yy = st === 'pressed' ? y + 5 : y;
  let g = st === 'focus' ? focusRing(x, y, w, h, r) : '';
  if (s) g += `<rect x="${x + 3}" y="${y + s}" width="${w}" height="${h}" rx="${r}" fill="${T.ink}" fill-opacity=".4"/>`;
  g += `<rect x="${x}" y="${yy}" width="${w}" height="${h}" rx="${r}" fill="${color}"/>`;
  g += `<rect x="${x + h * .3}" y="${yy + 5}" width="${w - h * .6}" height="${h * .28}" rx="${h * .14}" fill="#fff" fill-opacity=".35"/>`;
  g += `<rect x="${x}" y="${yy}" width="${w}" height="${h}" rx="${r}" fill="none" stroke="${T.ink}" stroke-width="3.5"/>`;
  g += txt(x + w / 2, yy + h / 2 + 2, label, o.size ?? h * .42, { anchor: 'middle', base: 'middle' });
  return g;
}
function badge(cx, cy, r, n, color) {
  return toy('circle', cx - r, cy - r, r * 2, r * 2, color, { ow: Math.max(2.5, r * .14), shadow: r * .18, glint: false }) +
    txt(cx, cy + r * .06, n, r * 1.15, { anchor: 'middle', base: 'middle', w: 700 });
}
function check(cx, cy, r, ok) {
  const c = ok ? C.good : C.bad;
  const mark = ok ? `<path d="M${cx - r * .45} ${cy} l${r * .3} ${r * .32} l${r * .6} ${-r * .62}" fill="none" stroke="${T.ink}" stroke-width="${r * .28}" stroke-linecap="round" stroke-linejoin="round"/>`
    : `<path d="M${cx - r * .35} ${cy - r * .35} l${r * .7} ${r * .7} M${cx + r * .35} ${cy - r * .35} l${-r * .7} ${r * .7}" stroke="${T.ink}" stroke-width="${r * .28}" stroke-linecap="round"/>`;
  return toy('circle', cx - r, cy - r, r * 2, r * 2, c, { ow: 2.5, shadow: 2, glint: false }) + mark;
}
function sparkle(cx, cy, r, c = '#fff') {
  return `<path d="M${cx} ${cy - r} Q${cx + r * .18} ${cy - r * .18} ${cx + r} ${cy} Q${cx + r * .18} ${cy + r * .18} ${cx} ${cy + r} Q${cx - r * .18} ${cy + r * .18} ${cx - r} ${cy} Q${cx - r * .18} ${cy - r * .18} ${cx} ${cy - r}Z" fill="${c}" stroke="${T.ink}" stroke-width="2"/>`;
}
function svg(w, h, body) {
  const d = defs.join(''); defs = [];
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${w} ${h}" width="${w}" height="${h}"><defs>${d}</defs>${body}</svg>`;
}

// ---- Shape Race: the "Tree" puzzle on a board (fractions of the board)
// Positions and sizes in board heights, so circles stay round; the picture is centred across the board.
const PIECES = [
  { k: 'circle', x: .06, y: .10, w: .42, h: .42, c: C.crown },
  { k: 'rect', x: .23, y: .50, w: .08, h: .38, c: C.trunk },
  { k: 'circle', x: .84, y: .08, w: .2, h: .2, c: C.sun },
  { k: 'tri', x: .60, y: .50, w: .52, h: .38, c: C.hill },
];
const PIC_W = 1.12;
function boardSide(x, y, w, h, o = {}) {
  // o.placed: indexes placed; o.held: [index, x, y] carried by the dot; o.wrong: [index, x, y]; o.player; o.easy
  const trayH = h * .2, gap = h * .03, by = y + trayH + gap, bh = h - trayH - gap, ox = x + (w - PIC_W * bh) / 2;
  const at = (p, px, py, s = 1) => [ox + px * bh, by + py * bh, p.w * bh * s, p.h * bh * s];
  let g = card(x, y, w, trayH, { fill: T.tray, ow: 3 }) + card(x, by, w, bh, { fill: T.board, ow: 3 });
  const placed = o.placed ?? [], held = o.held?.[0], wrong = o.wrong?.[0];
  const tray = PIECES.map((p, i) => i).filter(i => !placed.includes(i) && i !== held && i !== wrong);
  PIECES.forEach((p, i) => { if (!placed.includes(i)) { const [px, py, pw, ph] = at(p, p.x, p.y); g += target(p.k, px, py, pw, ph, o.easy === false ? T.neutral : dark(p.c, .12)); } });
  PIECES.forEach((p, i) => { if (placed.includes(i)) { const [px, py, pw, ph] = at(p, p.x, p.y); g += toy(p.k, px, py, pw, ph, p.c, { shadow: 3 }); } });
  if (o.wrong) {
    const p = PIECES[wrong], [px, py, pw, ph] = at(p, o.wrong[1], o.wrong[2]);
    g += geo(p.k, px, py, pw, ph, `fill="none" stroke="${C.bad}" stroke-width="9" stroke-linejoin="round"`);
    g += toy(p.k, px, py, pw, ph, p.c, { shadow: 4 }) + check(px + pw * .5, py + ph * .62, 14, false);
  }
  // tray pieces, small
  let tx = x + 20;
  tray.forEach(i => {
    const p = PIECES[i], s = Math.min((trayH * .7) / (p.h * bh), .8), pw = p.w * bh * s, ph = p.h * bh * s;
    g += toy(p.k, tx, y + (trayH - ph) / 2, pw, ph, p.c, { shadow: 2.5, ow: 2.5 });
    tx += pw + 24;
  });
  placed.forEach(i => { const p = PIECES[i], [px, py, pw] = at(p, p.x, p.y); g += sparkle(px + pw - 6, py + 8, 9, '#FFF6B0'); });
  const r = o.r ?? Math.max(14, bh * .07), pl = o.player ?? 1, col = C.p[pl - 1];
  const ctx = { r, col, pl, ox, by, bh };
  if (o.wrong) { const p = PIECES[wrong]; ctx.wrong = at(p, o.wrong[1], o.wrong[2]); }
  if (o.held) {
    const p = PIECES[held], [px, py, pw, ph] = at(p, o.held[1], o.held[2], 1.06);
    ctx.held = [px, py, pw, ph];
    g += toy(p.k, px, py, pw, ph, p.c, { shadow: 9 });
  }
  if (o.after) g += o.after(ctx);
  else if (o.player) g += worker(ox + .7 * bh, by + .3 * bh, r, col, pl, 'idle');
  return g;
}
function clockChip(cx, y, s, size, warn) {
  const w = size * 3.4, h = size * 1.45;
  return card(cx - w / 2, y, w, h, { fill: warn ? C.bad : T.paper, ow: 3.5 }) + txt(cx, y + h / 2 + 2, s, size, { anchor: 'middle', base: 'middle', w: 700 });
}

// ---- The worker: Shape Race's player dot as a character
function arrow(x, y, len, size, dir = 1) {
  const x2 = x + len * dir;
  return `<path d="M${x} ${y} H${x2}" stroke="${T.ink}" stroke-width="5" stroke-linecap="round"/><path d="M${x2 - size * .6 * dir} ${y - size * .55} L${x2 + 2 * dir} ${y} L${x2 - size * .6 * dir} ${y + size * .55}" fill="none" stroke="${T.ink}" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>`;
}
function worker(cx, cy, r, color, n, pose = 'idle', o = {}) {
  const ink = T.ink, arm = dark(color, .15), lw = Math.max(2, r * .09);
  const effort = ['push', 'pull', 'strain'].includes(pose);
  const lean = o.lean ?? ({ push: 12, pull: 14, move: 8, strain: 0, oops: -6, happy: 0 }[pose] ?? 0);
  const [sx, sy] = pose === 'strain' ? [1.13, .87] : pose === 'happy' ? [.94, 1.07] : [1, 1];
  const y = cy + (pose === 'happy' ? -r * .4 : 0), look = o.look ?? (pose === 'pull' ? [-1, 0] : pose === 'push' || pose === 'move' ? [1, 0] : [0, .3]);
  const H = { idle: [[-1.05, .8], [1.05, .8]], move: [[-1.15, .45], [.95, .9]], happy: [[-1.2, -1.15], [1.2, -1.15]],
    oops: [[-.92, -.72], [1.1, .75]], call: [[-1.05, .8], [1.3, -1.05]], away: [[-.95, .85], [.95, .85]] }[pose];
  const hands = o.hands ?? (H ?? [[-1.05, .8], [1.05, .8]]).map(([hx, hy]) => [cx + hx * r, y + hy * r]);
  let g = '';
  if (pose !== 'happy') g += `<ellipse cx="${cx}" cy="${cy + r * 1.02}" rx="${r * .8}" ry="${r * .16}" fill="${T.ink}" fill-opacity=".18"/>`;
  else g += `<ellipse cx="${cx}" cy="${cy + r * 1.02}" rx="${r * .55}" ry="${r * .12}" fill="${T.ink}" fill-opacity=".15"/>`;
  hands.forEach((h, i) => {
    if (!h) return;
    const s = [cx + (i ? .7 : -.7) * r, y + r * .15], mx = (s[0] + h[0]) / 2, my = (s[1] + h[1]) / 2 + r * .22;
    const d = `M${s[0]} ${s[1]} Q${mx} ${my} ${h[0]} ${h[1]}`;
    g += `<path d="${d}" fill="none" stroke="${ink}" stroke-width="${r * .42}" stroke-linecap="round"/><path d="${d}" fill="none" stroke="${arm}" stroke-width="${r * .22}" stroke-linecap="round"/>`;
  });
  const by = y + r, tf = `rotate(${lean} ${cx} ${by}) translate(${cx} ${by}) scale(${sx} ${sy}) translate(${-cx} ${-by})`;
  let b = toy('circle', cx - r, y - r, r * 2, r * 2, color, { ow: Math.max(2.5, r * .12), shadow: 0 });
  const ey = y - r * .3, ex = [cx - r * .34, cx + r * .34], lx = look[0] * r * .08, ly = look[1] * r * .08;
  ex.forEach((x, i) => {
    if (effort) {
      const d = i ? -1 : 1;
      b += `<path d="M${x - r * .15 * d} ${ey - r * .13} L${x + r * .1 * d} ${ey} L${x - r * .15 * d} ${ey + r * .13}" fill="none" stroke="${ink}" stroke-width="${lw * 1.1}" stroke-linecap="round" stroke-linejoin="round"/>`;
    } else if (pose === 'happy') {
      b += `<path d="M${x - r * .16} ${ey + r * .06} Q${x} ${ey - r * .22} ${x + r * .16} ${ey + r * .06}" fill="none" stroke="${ink}" stroke-width="${lw * 1.1}" stroke-linecap="round"/>`;
    } else if (pose === 'away') {
      b += `<path d="M${x - r * .15} ${ey} Q${x} ${ey + r * .1} ${x + r * .15} ${ey}" fill="none" stroke="${ink}" stroke-width="${lw}" stroke-linecap="round"/>`;
    } else {
      const big = pose === 'oops';
      b += `<ellipse cx="${x}" cy="${ey}" rx="${r * (big ? .23 : .19)}" ry="${r * (big ? .28 : .25)}" fill="#fff" stroke="${ink}" stroke-width="${lw * .8}"/>`;
      b += `<circle cx="${x + lx}" cy="${ey + ly + r * .03}" r="${r * (big ? .07 : .1)}" fill="${ink}"/>`;
    }
  });
  const my = y + r * .12;
  const mouths = {
    smile: `<path d="M${cx - r * .2} ${my} Q${cx} ${my + r * .2} ${cx + r * .2} ${my}" fill="none" stroke="${ink}" stroke-width="${lw}" stroke-linecap="round"/>`,
    grit: `<rect x="${cx - r * .27}" y="${my - r * .07}" width="${r * .54}" height="${r * .2}" rx="${r * .06}" fill="#fff" stroke="${ink}" stroke-width="${lw * .8}"/><path d="M${cx - r * .09} ${my - r * .07} v${r * .2} M${cx + r * .09} ${my - r * .07} v${r * .2} M${cx - r * .27} ${my + r * .03} h${r * .54}" stroke="${ink}" stroke-width="${lw * .6}"/>`,
    o: `<ellipse cx="${cx}" cy="${my + r * .04}" rx="${r * .09}" ry="${r * .12}" fill="${ink}"/>`,
    open: `<path d="M${cx - r * .22} ${my - r * .02} Q${cx} ${my + r * .36} ${cx + r * .22} ${my - r * .02} Z" fill="${ink}"/><ellipse cx="${cx}" cy="${my + r * .14}" rx="${r * .1}" ry="${r * .05}" fill="#FF7A9A"/>`,
    tongue: `<path d="M${cx - r * .2} ${my} Q${cx} ${my + r * .18} ${cx + r * .2} ${my}" fill="none" stroke="${ink}" stroke-width="${lw}" stroke-linecap="round"/><ellipse cx="${cx + r * .14}" cy="${my + r * .1}" rx="${r * .08}" ry="${r * .1}" fill="#FF7A9A" stroke="${ink}" stroke-width="${lw * .6}"/>`,
    wavy: `<path d="M${cx - r * .22} ${my + r * .06} q${r * .055} ${-r * .09} ${r * .11} 0 t${r * .11} 0 t${r * .11} 0 t${r * .11} 0" fill="none" stroke="${ink}" stroke-width="${lw}" stroke-linecap="round"/>`,
    flat: `<path d="M${cx - r * .12} ${my + r * .05} h${r * .24}" stroke="${ink}" stroke-width="${lw}" stroke-linecap="round"/>`,
  };
  b += mouths[{ push: 'grit', pull: 'grit', strain: 'grit', team: 'o', call: 'open', happy: 'open', rotate: 'tongue', oops: 'wavy', away: 'flat' }[pose] ?? 'smile'];
  b += txt(cx, y + r * .66, n, r * .42, { anchor: 'middle', base: 'middle', w: 700, fill: ink, extra: 'opacity=".75"' });
  g += `<g transform="${tf}">${b}</g>`;
  hands.forEach(h => { if (h) g += `<circle cx="${h[0]}" cy="${h[1]}" r="${r * .2}" fill="${light(color, .25)}" stroke="${ink}" stroke-width="${lw}"/>`; });
  if (effort || pose === 'oops') {
    const dx = cx + (lean >= 0 ? -1.05 : 1.05) * r, dy = y - r * .7;
    g += `<path d="M${dx} ${dy} q${r * .14} ${r * .22} 0 ${r * .3} q${-r * .14} ${-r * .08} 0 ${-r * .3}z" fill="#9BDDFF" stroke="${ink}" stroke-width="${lw * .7}"/>`;
  }
  if (pose === 'strain') g += `<path d="M${cx - r * 1.35} ${y - r * .2} q${-r * .12} ${r * .25} 0 ${r * .5} M${cx + r * 1.35} ${y - r * .2} q${r * .12} ${r * .25} 0 ${r * .5}" fill="none" stroke="${ink}" stroke-width="${lw}" stroke-linecap="round"/>`;
  if (pose === 'call') g += card(cx + r * .9, y - r * 2.3, r * 2.2, r * 1.1, { ow: 2.5 }) + txt(cx + r * 2, y - r * 1.62, 'Hey!', r * .55, { anchor: 'middle', w: 700 });
  if (pose === 'away') g = `<g opacity=".5">${g}</g>` + txt(cx + r * 1.1, y - r * .9, 'z z', r * .6, { w: 700, fill: T.onBg });
  if (pose === 'happy') g += sparkle(cx - r * 1.5, y - r * .2, r * .3, '#FFF6B0') + sparkle(cx + r * 1.55, y - r * .5, r * .25, '#FFF6B0');
  return g;
}

// ---- The Arena: a marble, a bumping hazard and the goal pad with its flag
function marble(cx, cy, r, color, n, dir = 1) {
  let g = toy('circle', cx - r, cy - r, r * 2, r * 2, color, { ow: 3.5, shadow: r * .2 });
  [-.32, .32].forEach(dx => {
    const ex = cx + dx * r + dir * r * .18, ey = cy - r * .12;
    g += `<ellipse cx="${ex}" cy="${ey}" rx="${r * .22}" ry="${r * .3}" fill="#fff" stroke="${T.ink}" stroke-width="2.5"/><circle cx="${ex + dir * r * .08}" cy="${ey + r * .04}" r="${r * .11}" fill="${T.ink}"/>`;
  });
  return g;
}
function flag(x, y, w, h) {
  let g = toy('rect', x, y + h * .45, w, h * .55, C.good, { glint: false });
  g += `<rect x="${x + w * .2}" y="${y}" width="6" height="${h * .75}" rx="3" fill="${T.paper}" stroke="${T.ink}" stroke-width="2.5"/>`;
  for (let i = 0; i < 3; i++) for (let j = 0; j < 2; j++) g += `<rect x="${x + w * .2 + 6 + i * 13}" y="${y + 2 + j * 13}" width="13" height="13" fill="${(i + j) % 2 ? T.ink : '#fff'}"/>`;
  g += `<rect x="${x + w * .2 + 6}" y="${y + 2}" width="39" height="26" fill="none" stroke="${T.ink}" stroke-width="2.5"/>`;
  return g;
}
function bumper(cx, cy, r) {
  return toy('circle', cx - r, cy - r, r * 2, r * 2, C.bad, { ow: 3.5, shadow: 5 }) +
    `<circle cx="${cx}" cy="${cy}" r="${r * .55}" fill="none" stroke="#fff" stroke-width="4"/><circle cx="${cx}" cy="${cy}" r="${r * .3}" fill="${dark(C.bad, .4)}" stroke="${T.ink}" stroke-width="2.5"/>`;
}

// ---- The phone: its D-pad, its face buttons and the phone frame every phone frame is drawn in
function pad(x, y, s) { // D-pad
  const a = s / 3;
  let g = `<path d="M${x + a} ${y} h${a} v${a} h${a} v${a} h${-a} v${a} h${-a} v${-a} h${-a} v${-a} h${a}z" transform="translate(4 5)" fill="${T.ink}" fill-opacity=".4"/>`;
  g += `<path d="M${x + a} ${y} h${a} v${a} h${a} v${a} h${-a} v${a} h${-a} v${-a} h${-a} v${-a} h${a}z" fill="${T.paper}" stroke="${T.ink}" stroke-width="3.5" stroke-linejoin="round"/>`;
  [[x + s / 2, y + a * .5, 0], [x + s - a * .5, y + s / 2, 90], [x + s / 2, y + s - a * .5, 180], [x + a * .5, y + s / 2, 270]].forEach(([cx, cy, r]) =>
    g += `<path d="M${cx} ${cy - 8} l8 10 h-16z" fill="${T.ink}" fill-opacity=".55" transform="rotate(${r} ${cx} ${cy})"/>`);
  return g;
}
function faces(cx, cy, r, gap) {
  let g = '';
  [['Y', 0, -1], ['X', -1, 0], ['B', 1, 0], ['A', 0, 1]].forEach(([k, dx, dy]) => {
    const x = cx + dx * gap, y = cy + dy * gap;
    g += toy('circle', x - r, y - r, r * 2, r * 2, C.face[k], { ow: 3.5, shadow: 5 }) + txt(x, y + 2, k, r * .95, { anchor: 'middle', base: 'middle', w: 700 });
  });
  return g;
}
function phone(w, h, body) {
  return `<rect x="0" y="0" width="${w + 36}" height="${h + 24}" rx="40" fill="#15121F"/><g transform="translate(18 12)"><clipPath id="ph${++uid}"><rect width="${w}" height="${h}" rx="26"/></clipPath><g clip-path="url(#ph${uid})">${body}</g></g>`;
}
function toggle(x, y, on) {
  return `<rect x="${x + 2}" y="${y + 4}" width="70" height="38" rx="19" fill="${T.ink}" fill-opacity=".35"/><rect x="${x}" y="${y}" width="70" height="38" rx="19" fill="${on ? C.good : '#D8D2C4'}" stroke="${T.ink}" stroke-width="3"/>` +
    toy('circle', on ? x + 36 : x + 4, y + 4, 30, 30, T.paper === '#FFF6E3' ? '#FFFFFF' : T.paper, { ow: 2.5, shadow: 0, glint: false });
}

// ---- render: every frame, or one alone with ?frame=N (0-based), &theme=sunny|night, &fx=0
const q = new URLSearchParams(location.search);
function renderFrames(F) {
  const out = document.getElementById('out'); out.innerHTML = '';
  const only = q.get('frame');
  F.forEach(([title, note, w, h, draw], i) => {
    if (only != null && +only !== i) return;
    uid = i * 1000; defs = [];
    const s = svg(w, h, draw());
    out.insertAdjacentHTML('beforeend', only != null ? s : `<figure><figcaption>${i + 1}. ${title} (${T.name}${FX ? '' : ', effects off'})<span>${note}</span></figcaption>${s}</figure>`);
  });
  document.querySelectorAll('.bar button').forEach(b => b.classList.toggle('on',
    (b.id === 'b-sunny' && T === PAL.sunny) || (b.id === 'b-night' && T === PAL.night) || (b.id === 'b-fx1' && FX) || (b.id === 'b-fx0' && !FX)));
}
function startPage(F) {
  T = PAL[q.get('theme')] ?? PAL.sunny; FX = q.get('fx') !== '0';
  if (q.get('frame') != null) { document.body.classList.add('single'); document.getElementById('head').remove(); }
  else {
    document.getElementById('b-sunny').onclick = () => { T = PAL.sunny; renderFrames(F); };
    document.getElementById('b-night').onclick = () => { T = PAL.night; renderFrames(F); };
    document.getElementById('b-fx1').onclick = () => { FX = true; renderFrames(F); };
    document.getElementById('b-fx0').onclick = () => { FX = false; renderFrames(F); };
  }
  document.fonts.ready.then(() => renderFrames(F));
  renderFrames(F);
}
