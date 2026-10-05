import MessagesView from '../MessagesView.vue';

// These exercise the component's own options object rather than a mounted
// instance: the wiring under test is which events may cancel the "stay on the
// newest message" follow, and that is plain logic on `this`.
const buildContext = (overrides = {}) => ({
  ...MessagesView.data(),
  queueScrollToLatestMessage: vi.fn(),
  fetchPreviousMessages: vi.fn(),
  releaseLatestMessage: MessagesView.methods.releaseLatestMessage,
  stopObservingComposerChrome: MessagesView.methods.stopObservingComposerChrome,
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

  it('sizes the composer so the To field can sit at the top of the panel', () => {
    const setEditorHeight = vi.fn();
    // The composer runs to y=900 and its To field starts at y=400, so it takes
    // up 500 of the 700 available — the writing area, now 300, is 200 short.
    // The list item reaches further down (y=1000) because of the min-height
    // that keeps the thread from peeking in; measuring to that instead would
    // undersize the writing area and push send off the bottom.
    const editor = { offsetHeight: 300 };
    const anchor = { getBoundingClientRect: () => ({ top: 400 }) };
    const context = buildContext({
      composerAnchorElement: () => anchor,
      composerElement: () => ({
        getBoundingClientRect: () => ({ bottom: 1000 }),
      }),
      conversationPanel: { clientHeight: 700 },
      resizableEditorWrapperRef: {
        $el: {
          getBoundingClientRect: () => ({ bottom: 900 }),
          querySelector: () => editor,
        },
        setEditorHeight,
      },
    });

    MessagesView.methods.expandComposerToFill.call(context);

    expect(setEditorHeight).toHaveBeenCalledWith(500);
  });

  it('leaves the composer alone once it already fills the panel', () => {
    const setEditorHeight = vi.fn();
    const anchor = { getBoundingClientRect: () => ({ top: 200 }) };
    const context = buildContext({
      composerAnchorElement: () => anchor,
      conversationPanel: { clientHeight: 700 },
      resizableEditorWrapperRef: {
        $el: {
          getBoundingClientRect: () => ({ bottom: 900 }),
          querySelector: () => ({ offsetHeight: 420 }),
        },
        setEditorHeight,
      },
    });

    MessagesView.methods.expandComposerToFill.call(context);

    expect(setEditorHeight).toHaveBeenCalledWith(420);
  });

  it('stops watching the mail fields once the composer closes', () => {
    const disconnect = vi.fn();
    const context = buildContext({ composerChromeObserver: { disconnect } });

    MessagesView.watch.composerOpen.call(context, false);

    expect(disconnect).toHaveBeenCalled();
    expect(context.composerChromeObserver).toBeNull();
  });

  it('falls back to the composer itself when there are no mail fields', () => {
    const composer = { querySelector: () => null };
    const context = buildContext({ composerElement: () => composer });

    expect(MessagesView.methods.composerAnchorElement.call(context)).toBe(
      composer
    );
  });

  it('stops following the newest message when the composer opens', () => {
    const context = buildContext({
      followLatestMessageUntil: Date.now() + 5000,
      $nextTick: vi.fn(),
    });

    MessagesView.methods.onOpenComposer.call(context, 'REPLY');

    expect(context.followLatestMessageUntil).toBe(0);
    expect(context.composerOpen).toBe(true);
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
