import { describe, it, expect } from 'vitest';
import { EmailQuoteExtractor } from '../emailQuoteExtractor.js';

const SAMPLE_EMAIL_HTML = `
<p>method</p>
<blockquote>
<p>On Mon, Sep 29, 2025 at 5:18 PM John <a href="mailto:shivam@chatwoot.com">shivam@chatwoot.com</a> wrote:</p>
<p>Hi</p>
<blockquote>
<p>On Mon, Sep 29, 2025 at 5:17 PM Shivam Mishra <a href="mailto:shivam@chatwoot.com">shivam@chatwoot.com</a> wrote:</p>
<p>Yes, it is.</p>
<p>On Mon, Sep 29, 2025 at 5:16 PM John from Shaneforwoot &lt; shaneforwoot@gmail.com&gt; wrote:</p>
<blockquote>
<p>Hey</p>
<p>On Mon, Sep 29, 2025 at 4:59 PM John shivam@chatwoot.com wrote:</p>
<p>This is another quoted quoted text reply</p>
<p>This is nice</p>
<p>On Mon, Sep 29, 2025 at 4:21 PM John from Shaneforwoot &lt; &gt; shaneforwoot@gmail.com&gt; wrote:</p>
<p>Hey there, this is a reply from Chatwoot, notice the quoted text</p>
<p>Hey there</p>
<p>This is an email text, enjoy reading this</p>
<p>-- Shivam Mishra, Chatwoot</p>
</blockquote>
</blockquote>
</blockquote>
`;

const EMAIL_WITH_SIGNATURE = `
<p>Latest reply here.</p>
<p>Thanks,</p>
<p>Jane Doe</p>
<blockquote>
  <p>On Mon, Sep 22, Someone wrote:</p>
  <p>Previous reply content</p>
</blockquote>
`;

const EMAIL_WITH_FOLLOW_UP_CONTENT = `
<blockquote>
  <p>Inline quote that should stay</p>
</blockquote>
<p>Internal note follows</p>
<p>Regards,</p>
`;

// Outlook: header block and old message are siblings after the new text.
const OUTLOOK_REPLY = `
<div class="elementToProof">Thinking 250 of each design.</div>
<div id="ms-outlook-mobile-signature">Get Outlook for iOS</div>
<hr style="display:inline-block;width:98%">
<div id="divRplyFwdMsg"><b>From:</b> Peach Labels<br><b>Sent:</b> Friday</div>
<div><p>Hi Ryan,</p><p>Previous agent reply</p></div>
`;

// Apple Mail: cite blockquotes nested inside the signature wrapper.
const APPLE_MAIL_REPLY = `
Should be purple
<div><div dir="ltr"><p>Sent from my iPhone</p></div>
<div dir="ltr"><blockquote type="cite">On Oct 22, 2026, at 4:31 PM, Peach Labels wrote:</blockquote></div>
<blockquote type="cite"><div dir="ltr"><p>Hi Fam, previous agent reply</p></div></blockquote></div>
`;

describe('EmailQuoteExtractor', () => {
  it('cuts Outlook history that follows the reply header as siblings', () => {
    const cleanedHtml = EmailQuoteExtractor.extractQuotes(OUTLOOK_REPLY);

    expect(cleanedHtml).toContain('Thinking 250 of each design.');
    expect(cleanedHtml).toContain('Get Outlook for iOS');
    expect(cleanedHtml).not.toContain('Previous agent reply');
    expect(cleanedHtml).not.toContain('<hr');
    expect(EmailQuoteExtractor.hasQuotes(OUTLOOK_REPLY)).toBe(true);
  });

  it('cuts nested Apple Mail cite blockquotes', () => {
    const cleanedHtml = EmailQuoteExtractor.extractQuotes(APPLE_MAIL_REPLY);

    expect(cleanedHtml).toContain('Should be purple');
    expect(cleanedHtml).toContain('Sent from my iPhone');
    expect(cleanedHtml).not.toContain('previous agent reply');
    expect(cleanedHtml).not.toContain('wrote:');
  });

  it('keeps a forward that has no new text before it', () => {
    const html =
      '<blockquote type="cite"><p>Forwarded content</p></blockquote><p>tail</p>';
    expect(EmailQuoteExtractor.extractQuotes(html)).toContain(
      'Forwarded content'
    );
  });

  it('removes blockquote-based quotes from the email body', () => {
    const cleanedHtml = EmailQuoteExtractor.extractQuotes(SAMPLE_EMAIL_HTML);

    const container = document.createElement('div');
    container.innerHTML = cleanedHtml;

    expect(container.querySelectorAll('blockquote').length).toBe(0);
    expect(container.textContent?.trim()).toBe('method');
    expect(container.textContent).not.toContain(
      'On Mon, Sep 29, 2025 at 5:18 PM'
    );
  });

  it('keeps blockquote fallback when it is not the last top-level element', () => {
    const cleanedHtml = EmailQuoteExtractor.extractQuotes(
      EMAIL_WITH_FOLLOW_UP_CONTENT
    );

    const container = document.createElement('div');
    container.innerHTML = cleanedHtml;

    expect(container.querySelector('blockquote')).not.toBeNull();
    expect(container.lastElementChild?.tagName).toBe('P');
  });

  it('detects quote indicators in nested blockquotes', () => {
    const result = EmailQuoteExtractor.hasQuotes(SAMPLE_EMAIL_HTML);
    expect(result).toBe(true);
  });

  it('does not flag blockquotes that are followed by other elements', () => {
    expect(EmailQuoteExtractor.hasQuotes(EMAIL_WITH_FOLLOW_UP_CONTENT)).toBe(
      false
    );
  });

  it('returns false when no quote indicators are present', () => {
    const html = '<p>Plain content</p>';
    expect(EmailQuoteExtractor.hasQuotes(html)).toBe(false);
  });

  it('removes trailing blockquotes while preserving trailing signatures', () => {
    const cleanedHtml = EmailQuoteExtractor.extractQuotes(EMAIL_WITH_SIGNATURE);

    expect(cleanedHtml).toContain('<p>Thanks,</p>');
    expect(cleanedHtml).toContain('<p>Jane Doe</p>');
    expect(cleanedHtml).not.toContain('<blockquote');
  });

  it('detects quotes for trailing blockquotes even when signatures follow text', () => {
    expect(EmailQuoteExtractor.hasQuotes(EMAIL_WITH_SIGNATURE)).toBe(true);
  });

  describe('HTML sanitization', () => {
    it('removes onerror handlers from img tags in extractQuotes', () => {
      const maliciousHtml = '<p>Hello</p><img src="x" onerror="alert(1)">';
      const cleanedHtml = EmailQuoteExtractor.extractQuotes(maliciousHtml);

      expect(cleanedHtml).not.toContain('onerror');
      expect(cleanedHtml).toContain('<p>Hello</p>');
    });

    it('removes onerror handlers from img tags in hasQuotes', () => {
      const maliciousHtml = '<p>Hello</p><img src="x" onerror="alert(1)">';
      // Should not throw and should safely check for quotes
      const result = EmailQuoteExtractor.hasQuotes(maliciousHtml);
      expect(result).toBe(false);
    });

    it('removes script tags in extractQuotes', () => {
      const maliciousHtml =
        '<p>Content</p><script>alert("xss")</script><p>More</p>';
      const cleanedHtml = EmailQuoteExtractor.extractQuotes(maliciousHtml);

      expect(cleanedHtml).not.toContain('<script');
      expect(cleanedHtml).not.toContain('alert');
      expect(cleanedHtml).toContain('<p>Content</p>');
      expect(cleanedHtml).toContain('<p>More</p>');
    });

    it('removes onclick handlers in extractQuotes', () => {
      const maliciousHtml = '<p onclick="alert(1)">Click me</p>';
      const cleanedHtml = EmailQuoteExtractor.extractQuotes(maliciousHtml);

      expect(cleanedHtml).not.toContain('onclick');
      expect(cleanedHtml).toContain('Click me');
    });

    it('removes javascript: URLs in extractQuotes', () => {
      const maliciousHtml = '<a href="javascript:alert(1)">Link</a>';
      const cleanedHtml = EmailQuoteExtractor.extractQuotes(maliciousHtml);

      // eslint-disable-next-line no-script-url
      expect(cleanedHtml).not.toContain('javascript:');
      expect(cleanedHtml).toContain('Link');
    });

    it('removes encoded payloads with event handlers in extractQuotes', () => {
      const maliciousHtml =
        '<img src="x" id="PHNjcmlwdD5hbGVydCgxKTwvc2NyaXB0Pg==" onerror="eval(atob(this.id))">';
      const cleanedHtml = EmailQuoteExtractor.extractQuotes(maliciousHtml);

      expect(cleanedHtml).not.toContain('onerror');
      expect(cleanedHtml).not.toContain('eval');
    });
  });
});
