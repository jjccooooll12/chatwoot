// FRESHDESK-SKIN: underline for the reply editor.
//
// @chatwoot/prosemirror-schema has no underline mark, so this module adds one
// on top of it: the schema mark, its markdown form (`<u>…</u>`, see
// shared/helpers/markdownIt/underline.js) and a parser that reads it back.
// Channels opt in with 'underline' in their FORMATTING marks.
import MarkdownIt from 'markdown-it';
import { Schema } from 'prosemirror-model';
import {
  MessageMarkdownSerializer,
  MessageMarkdownTransformer,
} from '@chatwoot/prosemirror-schema';
// The package entry is a prebuilt bundle; its parser mapping isn't reachable,
// so the underline-aware parser is the source build, whose mapping is.
import {
  MessageMarkdownTransformer as SourceMessageMarkdownTransformer,
  messageMdToPmMapping,
} from '@chatwoot/prosemirror-schema/src/schema/markdown/messageParser';
import underlinePlugin from 'shared/helpers/markdownIt/underline';

export const UNDERLINE = 'underline';

const underlineMarkSpec = {
  parseDOM: [{ tag: 'u' }, { style: 'text-decoration=underline' }],
  toDOM: () => ['u', 0],
};

// Serializing and parsing are keyed by name, and both are no-ops for a schema
// without the mark, so registering them once is safe for every editor.
MessageMarkdownSerializer.marks[UNDERLINE] = {
  open: '<u>',
  close: '</u>',
  mixable: true,
  expelEnclosingWhitespace: true,
};
messageMdToPmMapping.u = { mark: UNDERLINE };

// Same tokenizer setup as the library's message parser, plus `<u>`.
const underlineTokenizer = MarkdownIt('commonmark', {
  html: false,
  linkify: false,
})
  .enable(['entity', 'escape'])
  .disable(['table', 'hr', 'heading', 'lheading'], true)
  .use(underlinePlugin);

export const hasUnderline = schema => Boolean(schema?.marks[UNDERLINE]);

/** The schema with an underline mark allowed wherever marks are restricted. */
export function withUnderline(schema) {
  let { nodes } = schema.spec;
  schema.spec.nodes.forEach((name, spec) => {
    if (typeof spec.marks === 'string') {
      nodes = nodes.update(name, {
        ...spec,
        marks: `${spec.marks} ${UNDERLINE}`.trim(),
      });
    }
  });
  return new Schema({
    nodes,
    marks: schema.spec.marks.addToEnd(UNDERLINE, underlineMarkSpec),
    topNode: schema.spec.topNode,
  });
}

/** A markdown parser for this schema; only reads `<u>` when it can hold it. */
export const createMessageParser = schema =>
  hasUnderline(schema)
    ? new SourceMessageMarkdownTransformer(schema, underlineTokenizer)
    : new MessageMarkdownTransformer(schema);
