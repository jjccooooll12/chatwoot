import { MESSAGE_TYPE } from 'shared/constants/messages';

/**
 * The newest thing actually said in a thread — a reply, an incoming mail or a
 * private note. Status/assignment activity lines are skipped: they are not
 * what an agent opening a ticket is looking for, and they are hidden from the
 * thread by default anyway.
 *
 * @param {Array} messages - Messages in chronological order (oldest first).
 * @returns {Number|null} - Id of the newest non-activity message.
 */
export const findLatestMessageId = (messages = []) => {
  for (let index = messages.length - 1; index >= 0; index -= 1) {
    const message = messages[index];
    if (message && message.message_type !== MESSAGE_TYPE.ACTIVITY) {
      return message.id ?? null;
    }
  }
  return null;
};

/**
 * Scroll offset that brings an element to the top of its scroll panel, leaving
 * `gap` above it. Both tops are viewport-relative (getBoundingClientRect), so
 * the current scroll offset is carried over.
 *
 * Only the lower bound is clamped here — the browser clamps the upper one, so
 * a thread with too little content below simply settles as high as it can.
 *
 * @returns {Number} - The scrollTop to apply to the panel.
 */
export const calculateTopAlignedScrollTop = ({
  currentScrollTop,
  elementTop,
  panelTop,
  gap = 0,
}) => Math.max(0, currentScrollTop + elementTop - panelTop - gap);
