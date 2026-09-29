import { MESSAGE_TYPE } from 'shared/constants/messages';

/**
 * The things actually said in a thread — replies, incoming mail, private notes
 * — newest first. Status/assignment activity lines are left out: they are not
 * what an agent opening a ticket is looking for, and they are hidden from the
 * thread by default anyway.
 *
 * Returns every candidate rather than just the newest because a message with
 * no content and no attachments renders nothing at all, and the view still has
 * to land on the last thing the agent can actually see.
 *
 * @param {Array} messages - Messages in chronological order (oldest first).
 * @returns {Array} - Ids of the non-activity messages, newest first.
 */
export const findLatestMessageIds = (messages = []) =>
  messages
    .filter(
      message =>
        message &&
        message.id != null &&
        message.message_type !== MESSAGE_TYPE.ACTIVITY
    )
    .map(message => message.id)
    .reverse();

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
