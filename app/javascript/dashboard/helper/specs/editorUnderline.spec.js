import {
  buildMessageSchema,
  MessageMarkdownSerializer,
} from '@chatwoot/prosemirror-schema';
import {
  withUnderline,
  createMessageParser,
} from 'dashboard/helper/editorUnderline';
import MessageFormatter from 'shared/helpers/MessageFormatter';

describe('editorUnderline', () => {
  const schema = withUnderline(
    buildMessageSchema(['strong', 'em', 'link'], ['bulletList', 'orderedList'])
  );

  it('round-trips underline through markdown', () => {
    const markdown = 'Hi <u>Tom</u>, **bold <u>both</u>**';
    const doc = createMessageParser(schema).parse(markdown);
    const underlined = [];
    doc.descendants(node => {
      if (node.marks.some(mark => mark.type.name === 'underline')) {
        underlined.push(node.text);
      }
    });
    expect(underlined).toEqual(['Tom', 'both']);
    expect(MessageMarkdownSerializer.serialize(doc)).toBe(markdown);
  });

  it('leaves an unmatched tag as text', () => {
    const doc = createMessageParser(schema).parse('a <u>b');
    expect(doc.textContent).toBe('a <u>b');
  });

  it('renders underline in the thread', () => {
    const html = new MessageFormatter('x <u>y</u> <b>z</b>').formattedMessage;
    expect(html).toContain('<u>y</u>');
    expect(html).not.toContain('<b>');
  });
});
