// FRESHDESK-SKIN: keep customer email text readable.
//
// Emails often hard-code a text colour meant for their own background, e.g.
// light grey text for a dark email body. The dark background usually gets lost
// when we render the email (body bgcolor and friends are dropped), so the text
// ends up pale grey on our white card and is almost invisible
// (ticket 2611083). After an email renders, any text with too little contrast
// against whatever is actually behind it falls back to the card's text colour.

const MIN_CONTRAST = 3;

export const parseColor = value => {
  const match = /^rgba?\(([^)]+)\)$/i.exec((value || '').trim());
  if (!match) return null;
  const parts = match[1].split(/[\s,/]+/).filter(Boolean);
  if (parts.length < 3) return null;
  const [r, g, b] = parts.slice(0, 3).map(Number);
  let a = 1;
  if (parts[3] !== undefined) {
    a = parts[3].endsWith('%')
      ? parseFloat(parts[3]) / 100
      : parseFloat(parts[3]);
  }
  if ([r, g, b, a].some(Number.isNaN)) return null;
  return { r, g, b, a };
};

const channel = c => {
  const s = c / 255;
  return s <= 0.03928 ? s / 12.92 : ((s + 0.055) / 1.055) ** 2.4;
};

export const luminance = ({ r, g, b }) =>
  0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b);

export const contrastRatio = (fg, bg) => {
  const l1 = luminance(fg);
  const l2 = luminance(bg);
  return (Math.max(l1, l2) + 0.05) / (Math.min(l1, l2) + 0.05);
};

// Blend a translucent colour over the background it sits on.
const blend = (top, bottom) => ({
  r: top.r * top.a + bottom.r * (1 - top.a),
  g: top.g * top.a + bottom.g * (1 - top.a),
  b: top.b * top.a + bottom.b * (1 - top.a),
  a: 1,
});

const WHITE = { r: 255, g: 255, b: 255, a: 1 };

// First background that is actually painted, walking up from `el`.
const effectiveBackground = (el, view) => {
  let node = el;
  while (node && node.nodeType === 1) {
    const bg = parseColor(view.getComputedStyle(node).backgroundColor);
    if (bg && bg.a >= 0.5) return bg.a < 1 ? blend(bg, WHITE) : bg;
    node = node.parentElement;
  }
  return WHITE;
};

const hasOwnText = el =>
  Array.from(el.childNodes).some(
    n => n.nodeType === 3 && n.textContent.trim() !== ''
  );

// Fix every element under `root` whose own text is unreadable on its
// background. `fallbackColor` is the CSS colour to use instead. Returns the
// number of elements changed.
export const fixUnreadableText = (root, fallbackColor) => {
  if (!root) return 0;
  const view = root.ownerDocument?.defaultView;
  if (!view) return 0;
  let fixed = 0;
  root.querySelectorAll('*').forEach(el => {
    if (!hasOwnText(el)) return;
    const fg = parseColor(view.getComputedStyle(el).color);
    if (!fg) return;
    const bg = effectiveBackground(el, view);
    const solidFg = fg.a < 1 ? blend(fg, bg) : fg;
    if (contrastRatio(solidFg, bg) >= MIN_CONTRAST) return;
    el.style.setProperty('color', fallbackColor, 'important');
    fixed += 1;
  });
  return fixed;
};
