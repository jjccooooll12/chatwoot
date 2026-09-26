import {
  calculateTopAlignedScrollTop,
  findLatestMessageId,
} from '../latestMessageHelper';
import { MESSAGE_TYPE } from 'shared/constants/messages';

const incoming = id => ({ id, message_type: MESSAGE_TYPE.INCOMING });
const outgoing = id => ({ id, message_type: MESSAGE_TYPE.OUTGOING });
const activity = id => ({ id, message_type: MESSAGE_TYPE.ACTIVITY });
const privateNote = id => ({
  id,
  message_type: MESSAGE_TYPE.OUTGOING,
  private: true,
});

describe('findLatestMessageId', () => {
  it('returns the last message in the thread', () => {
    expect(findLatestMessageId([incoming(1), outgoing(2), incoming(3)])).toBe(
      3
    );
  });

  it('skips trailing activity lines', () => {
    expect(
      findLatestMessageId([incoming(1), outgoing(2), activity(3), activity(4)])
    ).toBe(2);
  });

  it('counts a private note as the latest message', () => {
    expect(findLatestMessageId([incoming(1), privateNote(2)])).toBe(2);
  });

  it('returns null when there is nothing but activities', () => {
    expect(findLatestMessageId([activity(1), activity(2)])).toBeNull();
  });

  it('returns null for an empty or missing list', () => {
    expect(findLatestMessageId([])).toBeNull();
    expect(findLatestMessageId()).toBeNull();
  });
});

describe('calculateTopAlignedScrollTop', () => {
  it('scrolls a message below the fold up to the top', () => {
    expect(
      calculateTopAlignedScrollTop({
        currentScrollTop: 0,
        elementTop: 900,
        panelTop: 100,
        gap: 16,
      })
    ).toBe(784);
  });

  it('carries over the panel current offset', () => {
    expect(
      calculateTopAlignedScrollTop({
        currentScrollTop: 500,
        elementTop: 300,
        panelTop: 100,
        gap: 16,
      })
    ).toBe(684);
  });

  it('scrolls back up for a message already above the fold', () => {
    expect(
      calculateTopAlignedScrollTop({
        currentScrollTop: 800,
        elementTop: 20,
        panelTop: 100,
        gap: 16,
      })
    ).toBe(704);
  });

  it('never returns a negative offset', () => {
    expect(
      calculateTopAlignedScrollTop({
        currentScrollTop: 0,
        elementTop: 100,
        panelTop: 100,
        gap: 16,
      })
    ).toBe(0);
  });

  it('leaves no gap by default', () => {
    expect(
      calculateTopAlignedScrollTop({
        currentScrollTop: 0,
        elementTop: 500,
        panelTop: 100,
      })
    ).toBe(400);
  });
});
