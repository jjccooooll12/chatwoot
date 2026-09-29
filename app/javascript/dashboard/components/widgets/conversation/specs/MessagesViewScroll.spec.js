import MessagesView from '../MessagesView.vue';

// These exercise the component's own options object rather than a mounted
// instance: the wiring under test is which events may cancel the "stay on the
// newest message" follow, and that is plain logic on `this`.
const buildContext = (overrides = {}) => ({
  ...MessagesView.data(),
  queueScrollToLatestMessage: vi.fn(),
  fetchPreviousMessages: vi.fn(),
  ...overrides,
});

const scroll = (context, scrollTop = 0) =>
  MessagesView.methods.handleScroll.call(context, { target: { scrollTop } });

describe('MessagesView — following the newest message', () => {
  it('starts following when a ticket is opened', () => {
    const context = buildContext();
    MessagesView.methods.followLatestMessage.call(context);

    expect(context.followLatestMessageUntil).toBeGreaterThan(Date.now());
    expect(context.queueScrollToLatestMessage).toHaveBeenCalled();
  });

  it('keeps following across scroll events', () => {
    // A scroll event fires for our own scrolling and for the browser's scroll
    // anchoring as older messages load in — neither means the agent scrolled.
    // Treating them as such left tickets opening on their oldest message.
    const context = buildContext();
    MessagesView.methods.followLatestMessage.call(context);
    const deadline = context.followLatestMessageUntil;

    scroll(context, 0);
    scroll(context, 420);

    expect(context.followLatestMessageUntil).toBe(deadline);
  });

  it('stops following once the agent scrolls for themselves', () => {
    const context = buildContext();
    MessagesView.methods.followLatestMessage.call(context);
    MessagesView.methods.releaseLatestMessage.call(context);

    expect(context.followLatestMessageUntil).toBe(0);
  });

  it('re-aligns when the thread loads in under us', () => {
    const context = buildContext({
      followLatestMessageUntil: Date.now() + 500,
    });
    MessagesView.watch.threadAnchor.call(context);

    expect(context.queueScrollToLatestMessage).toHaveBeenCalledTimes(1);
  });

  it('re-aligns as images in a mail body finish loading', () => {
    const context = buildContext({
      followLatestMessageUntil: Date.now() + 500,
      scrollToLatestMessage: vi.fn(),
    });
    MessagesView.methods.onPanelContentLoad.call(context);
    expect(context.scrollToLatestMessage).toHaveBeenCalledTimes(1);

    const released = buildContext({
      followLatestMessageUntil: 0,
      scrollToLatestMessage: vi.fn(),
    });
    MessagesView.methods.onPanelContentLoad.call(released);
    expect(released.scrollToLatestMessage).not.toHaveBeenCalled();
  });

  it('leaves the thread alone once released or timed out', () => {
    const released = buildContext({ followLatestMessageUntil: 0 });
    MessagesView.watch.threadAnchor.call(released);
    expect(released.queueScrollToLatestMessage).not.toHaveBeenCalled();

    const expired = buildContext({ followLatestMessageUntil: Date.now() - 1 });
    MessagesView.watch.threadAnchor.call(expired);
    expect(expired.queueScrollToLatestMessage).not.toHaveBeenCalled();
  });
});
