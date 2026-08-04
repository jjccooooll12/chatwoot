/**
 * Determines the last non-activity message between store and API messages.
 * @param {Object} messageInStore - The last non-activity message from the store.
 * @param {Object} messageFromAPI - The last non-activity message from the API.
 * @returns {Object} The latest non-activity message.
 */
const getLastNonActivityMessage = (messageInStore, messageFromAPI) => {
  // If both API value and store value for last non activity message
  // are available, then return the latest one.
  if (messageInStore && messageFromAPI) {
    return messageInStore.created_at >= messageFromAPI.created_at
      ? messageInStore
      : messageFromAPI;
  }
  // Otherwise, return whichever is available
  return messageInStore || messageFromAPI;
};

/**
 * Filters out duplicate source messages from an array of messages.
 * @param {Array} messages - The array of messages to filter.
 * @returns {Array} An array of messages without duplicates.
 */
export const filterDuplicateSourceMessages = (messages = []) => {
  const messagesWithoutDuplicates = [];
  // We cannot use Map or any short hand method as it returns the last message with the duplicate ID
  // We should return the message with smaller id when there is a duplicate
  messages.forEach(m1 => {
    if (m1.source_id) {
      const index = messagesWithoutDuplicates.findIndex(
        m2 => m1.source_id === m2.source_id
      );

      if (index < 0) {
        messagesWithoutDuplicates.push(m1);
      }
    } else {
      messagesWithoutDuplicates.push(m1);
    }
  });
  return messagesWithoutDuplicates;
};

/**
 * Retrieves the last message from a conversation, prioritizing non-activity messages.
 * @param {Object} m - The conversation object containing messages.
 * @returns {Object} The last message of the conversation.
 */
export const getLastMessage = m => {
  const lastMessageIncludingActivity = m.messages[m.messages.length - 1];

  const nonActivityMessages = m.messages.filter(
    message => message.message_type !== 2
  );
  const lastNonActivityMessageInStore =
    nonActivityMessages[nonActivityMessages.length - 1];

  const lastNonActivityMessageFromAPI = m.last_non_activity_message;

  // If API value and store value for last non activity message
  // is empty, then return the last activity message
  if (!lastNonActivityMessageInStore && !lastNonActivityMessageFromAPI) {
    return lastMessageIncludingActivity;
  }

  return getLastNonActivityMessage(
    lastNonActivityMessageInStore,
    lastNonActivityMessageFromAPI
  );
};

/**
 * Filters messages that have been read by the agent.
 * @param {Array} messages - The array of messages to filter.
 * @param {number} agentLastSeenAt - The timestamp of when the agent last saw the messages.
 * @returns {Array} An array of read messages.
 */
export const getReadMessages = (messages, agentLastSeenAt) => {
  return messages.filter(
    message => message.created_at * 1000 <= agentLastSeenAt * 1000
  );
};

/**
 * Filters messages that have not been read by the agent.
 * @param {Array} messages - The array of messages to filter.
 * @param {number} agentLastSeenAt - The timestamp of when the agent last saw the messages.
 * @returns {Array} An array of unread messages.
 */
export const getUnreadMessages = (messages, agentLastSeenAt) => {
  return messages.filter(
    message => message.created_at * 1000 > agentLastSeenAt * 1000
  );
};

/**
 * The customer-facing ticket number (yymmdd + that day's counter, e.g. 2608021).
 * This is the ONLY identifier that should ever be shown to a human — in the UI,
 * in email subjects, on call cards, in confirmation dialogs. The raw display_id
 * stays an internal routing/API key.
 *
 * Conversation payloads reach the dashboard in several shapes: the conversation
 * API serialises `ticket_number` at the top level, the search store camelizes it
 * to `ticketNumber`, and websocket/older payloads carry it inside
 * additional_attributes. This resolves all of them.
 *
 * @param {Object} conversation - A conversation in any of the shapes above.
 * @returns {string|number|undefined} The ticket number, falling back to the
 *   display id only for records that predate the scheme.
 */
export const getTicketNumber = (conversation = {}) => {
  const attrs =
    conversation.additional_attributes ||
    conversation.additionalAttributes ||
    {};

  return (
    conversation.ticket_number ||
    conversation.ticketNumber ||
    attrs.ticket_number ||
    attrs.ticketNumber ||
    conversation.display_id ||
    conversation.displayId ||
    conversation.id
  );
};
