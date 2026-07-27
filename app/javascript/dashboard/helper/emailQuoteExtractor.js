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

    if (this.findTrailingBlockquote(tempDiv)) {
      return true;
    }

    // Check for text-based quotes
    const textNodeQuotes = this.findTextNodeQuotes(tempDiv);
    return textNodeQuotes.length > 0;
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
