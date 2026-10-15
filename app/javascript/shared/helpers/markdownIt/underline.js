// FRESHDESK-SKIN: underline. Markdown has no underline syntax, so the reply
// editor stores it as a literal `<u>…</u>` pair. markdown-it runs with
// `html: false`, which would print those tags as text; this rule turns exactly
// that pair (nothing else) into `u_open` / `u_close` tokens. The server keeps
// the same two tags when it renders the email (BaseMarkdownRenderer).
const OPEN = '<u>';
const CLOSE = '</u>';

const underlineRule = (state, silent) => {
  const { src, pos } = state;
  if (src.charCodeAt(pos) !== 0x3c /* < */) return false;

  if (src.startsWith(OPEN, pos)) {
    // Only an opener that is closed later in the same paragraph.
    if (src.indexOf(CLOSE, pos + OPEN.length) === -1) return false;
    if (!silent) {
      state.push('u_open', 'u', 1);
      state.underlineDepth = (state.underlineDepth || 0) + 1;
    }
    state.pos += OPEN.length;
    return true;
  }

  if (src.startsWith(CLOSE, pos) && state.underlineDepth > 0) {
    if (!silent) {
      state.push('u_close', 'u', -1);
      state.underlineDepth -= 1;
    }
    state.pos += CLOSE.length;
    return true;
  }

  return false;
};

export default function underlinePlugin(md) {
  md.inline.ruler.before('emphasis', 'underline', underlineRule);
}
