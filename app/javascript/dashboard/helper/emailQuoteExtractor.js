import DOMPurify from 'dompurify';

// Quote detection strategies
const QUOTE_INDICATORS = [
  '.gmail_quote_container',
  '.gmail_quote',
  '.OutlookQuote',
  '.email-quote',
  '.quoted-text',
  '.quote',
  '[class*="quote"]',
  '[class*="Quote"]',
];

const BLOCKQUOTE_FALLBACK_SELECTOR = 'blockquote';

// FRESHDESK-SKIN: where a reply's quoted history starts. Outlook puts its
// "From/Sent/To" header and the old message as *siblings* after the new text,
// and Apple Mail nests its cite blockquote inside wrappers, so removing just
// the matched element left the whole history on screen. Everything from the
// first of these to the end of the email is history.
const REPLY_START_SELECTORS = [
  'blockquote[type="cite"]',
  '#divRplyFwdMsg',
  '#appendonsend',
  '#mail-editor-reference-message-container',
  '.moz-cite-prefix',
  'div[style*="border-top:solid #E1E1E1"]',
  'div[style*="border-top: solid rgb(225, 225, 225)"]',
  'div[style*="border-top:solid #B5C4DF"]',
];

// A line that opens quoted history: "On <date>, <name> wrote:" (and the
// languages our customers write in) or Outlook's plain-text separator.
const REPLY_HEADER_PATTERNS = [
  /On .+(wrote|écrit):?\s*$/i,
  /(ha scritto|a écrit|schrieb|escribió|napisał|schreef):\s*$/i,
  /-----\s*Original Message\s*-----/i,
];

// Regex patterns for quote identification
const QUOTE_PATTERNS = [
  /On .* wrote:/i,
  /-----Original Message-----/i,
  /Sent: /i,
  /From: /i,
];

export class EmailQuoteExtractor {
  /**
   * Remove quotes from email HTML and return cleaned HTML
   * @param {string} htmlContent - Full HTML content of the email
   * @returns {string} HTML content with quotes removed
   */
  static extractQuotes(htmlContent) {
    // Create a temporary DOM element to parse HTML
    const tempDiv = document.createElement('div');
    tempDiv.innerHTML = DOMPurify.sanitize(htmlContent);

    // Remove elements matching class selectors
    QUOTE_INDICATORS.forEach(selector => {
      tempDiv.querySelectorAll(selector).forEach(el => {
        el.remove();
      });
    });

    this.removeFromReplyStart(tempDiv);
    this.removeTrailingBlockquote(tempDiv);

    // Remove text-based quotes
    const textNodeQuotes = this.findTextNodeQuotes(tempDiv);
    textNodeQuotes.forEach(el => {
      el.remove();
    });

    return tempDiv.innerHTML;
  }

  /**
   * Check if HTML content contains any quotes
   * @param {string} htmlContent - Full HTML content of the email
   * @returns {boolean} True if quotes are detected, false otherwise
   */
  static hasQuotes(htmlContent) {
    const tempDiv = document.createElement('div');
    tempDiv.innerHTML = DOMPurify.sanitize(htmlContent);

    // Check for class-based quotes
    // eslint-disable-next-line no-restricted-syntax
    for (const selector of QUOTE_INDICATORS) {
      if (tempDiv.querySelector(selector)) {
        return true;
      }
    }

    if (this.findReplyStart(tempDiv) || this.findTrailingBlockquote(tempDiv)) {
      return true;
    }

    // Check for text-based quotes
    const textNodeQuotes = this.findTextNodeQuotes(tempDiv);
    return textNodeQuotes.length > 0;
  }

  /**
   * The node where a reply's quoted history begins, or null. Only counts when
   * the customer wrote something before it — a bare forward stays whole.
   * @param {Element} rootElement
   * @returns {Node|null}
   */
  static findReplyStart(rootElement) {
    const candidates = REPLY_START_SELECTORS.flatMap(selector =>
      Array.from(rootElement.querySelectorAll(selector))
    );

    const treeWalker = document.createTreeWalker(
      rootElement,
      NodeFilter.SHOW_TEXT
    );
    for (
      let node = treeWalker.nextNode();
      node !== null;
      node = treeWalker.nextNode()
    ) {
      if (REPLY_HEADER_PATTERNS.some(pattern => pattern.test(node.textContent))) {
        candidates.push(node);
        break;
      }
    }
    // Outlook plain-text headers: a "From:" line followed by "Sent:"/"Date:".
    const fromBlock = Array.from(rootElement.querySelectorAll('div, p')).find(
      el => /^\s*From:[\s\S]*\b(Sent|Date):/.test(el.textContent)
    );
    if (fromBlock) candidates.push(fromBlock);

    const first = candidates.sort((a, b) =>
      // eslint-disable-next-line no-bitwise
      a.compareDocumentPosition(b) & Node.DOCUMENT_POSITION_FOLLOWING ? -1 : 1
    )[0];
    if (!first) return null;

    const before = document.createRange();
    before.setStart(rootElement, 0);
    before.setEndBefore(first);
    const hasNewText = Boolean(before.toString().trim());
    return hasNewText ? first : null;
  }

  /**
   * Remove the quoted history: the reply start, everything after it, and an
   * Outlook <hr> separator right before it.
   * @param {Element} rootElement
   */
  static removeFromReplyStart(rootElement) {
    const start = this.findReplyStart(rootElement);
    if (!start) return;

    if (start.previousElementSibling?.tagName === 'HR') {
      start.previousElementSibling.remove();
    }
    for (let node = start; node && node !== rootElement; ) {
      while (node.nextSibling) node.nextSibling.remove();
      node = node.parentNode;
    }
    start.remove();
  }

  /**
   * Find nodes that make up quote-like content.
   *
   * Plain-text emails (no gmail_quote/blockquote wrapper — e.g. a reply typed
   * into a bare mailto: body) put the quote marker ("On ... wrote:") as a text
   * node directly alongside <br> siblings inside one flat container, alongside
   * the sender's own new text. Removing the *whole* parent block in that case
   * would delete genuine new content along with the quote. Instead, when the
   * marker's block has real content before it, only the marker onward is
   * removed; the whole block is only removed when there's nothing genuine
   * ahead of the marker (the normal case for a block that is only a quote).
   * @param {Element} rootElement - Root element to search
   * @returns {Node[]} Nodes to remove (elements and/or text nodes)
   */
  static findTextNodeQuotes(rootElement) {
    const nodesToRemove = [];
    const treeWalker = document.createTreeWalker(
      rootElement,
      NodeFilter.SHOW_TEXT,
      null,
      false
    );

    for (
      let currentNode = treeWalker.nextNode();
      currentNode !== null;
      currentNode = treeWalker.nextNode()
    ) {
      const isQuoteLike = QUOTE_PATTERNS.some(pattern =>
        pattern.test(currentNode.textContent)
      );

      if (isQuoteLike) {
        const parentBlock = this.findParentBlock(currentNode);
        if (!parentBlock) continue; // eslint-disable-line no-continue

        if (this.hasGenuineContentBefore(parentBlock, currentNode)) {
          this.nodesFromMarkerOnward(parentBlock, currentNode).forEach(node => {
            if (!nodesToRemove.includes(node)) nodesToRemove.push(node);
          });
        } else if (!nodesToRemove.includes(parentBlock)) {
          nodesToRemove.push(parentBlock);
        }
      }
    }

    return nodesToRemove;
  }

  /**
   * Whether `block` has any real (non-empty, non-<br>) content before `markerNode`.
   * @param {Element} block
   * @param {Node} markerNode
   * @returns {boolean}
   */
  static hasGenuineContentBefore(block, markerNode) {
    const children = Array.from(block.childNodes);
    const markerIndex = children.indexOf(markerNode);
    const before =
      markerIndex === -1 ? children : children.slice(0, markerIndex);

    return before.some(child => {
      if (child.nodeType === Node.TEXT_NODE) {
        return Boolean(child.textContent.trim());
      }
      return child.nodeType === Node.ELEMENT_NODE && child.tagName !== 'BR';
    });
  }

  /**
   * Sibling nodes from `markerNode` through the end of `block`, including the
   * line break immediately preceding the marker (if any) so no dangling blank
   * line is left where the quote used to start.
   * @param {Element} block
   * @param {Node} markerNode
   * @returns {Node[]}
   */
  static nodesFromMarkerOnward(block, markerNode) {
    const children = Array.from(block.childNodes);
    const markerIndex = children.indexOf(markerNode);
    if (markerIndex === -1) return [];

    const startIndex =
      children[markerIndex - 1]?.tagName === 'BR'
        ? markerIndex - 1
        : markerIndex;
    return children.slice(startIndex);
  }

  /**
   * Find the closest block-level parent element by recursively traversing up the DOM tree.
   * This method searches for common block-level elements like DIV, P, BLOCKQUOTE, and SECTION
   * that contain the text node. It's used to identify and remove entire block-level elements
   * that contain quote-like text, rather than just removing the text node itself. This ensures
   * proper structural removal of quoted content while maintaining HTML integrity.
   * @param {Node} node - Starting node to find parent
   * @returns {Element|null} Block-level parent element
   */
  static findParentBlock(node) {
    const blockElements = ['DIV', 'P', 'BLOCKQUOTE', 'SECTION'];
    let current = node.parentElement;

    while (current) {
      if (blockElements.includes(current.tagName)) {
        return current;
      }
      current = current.parentElement;
    }

    return null;
  }

  /**
   * Remove fallback blockquote if it is the last top-level element.
   * @param {Element} rootElement - Root element containing the HTML
   */
  static removeTrailingBlockquote(rootElement) {
    const trailingBlockquote = this.findTrailingBlockquote(rootElement);
    trailingBlockquote?.remove();
  }

  /**
   * Locate a fallback blockquote that is the last top-level element.
   * @param {Element} rootElement - Root element containing the HTML
   * @returns {Element|null} The trailing blockquote element if present
   */
  static findTrailingBlockquote(rootElement) {
    const lastElement = rootElement.lastElementChild;
    if (lastElement?.matches?.(BLOCKQUOTE_FALLBACK_SELECTOR)) {
      return lastElement;
    }
    return null;
  }
}
