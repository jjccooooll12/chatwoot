<script setup>
import { computed, reactive, ref, watch } from 'vue';
import Message from './Message.vue';
import { MESSAGE_TYPES } from './constants.js';
import { useCamelCase } from 'dashboard/composables/useTransformKeys';
import { useMapGetter } from 'dashboard/composables/store.js';
import MessageApi from 'dashboard/api/inbox/message.js';
import { useI18n } from 'vue-i18n';
import { INBOX_TYPES } from 'dashboard/helper/inbox';

/**
 * Props definition for the component
 * @typedef {Object} Props
 * @property {Array} readMessages - Array of read messages
 * @property {Array} unReadMessages - Array of unread messages
 * @property {Number} currentUserId - ID of the current user
 * @property {Boolean} isAnEmailChannel - Whether this is an email channel
 * @property {Object} inboxSupportsReplyTo - Inbox reply support configuration
 * @property {Array} messages - Array of all messages [These are not in camelcase]
 */
const props = defineProps({
  currentUserId: {
    type: Number,
    required: true,
  },
  firstUnreadId: {
    type: Number,
    default: null,
  },
  isAnEmailChannel: {
    type: Boolean,
    default: false,
  },
  inboxSupportsReplyTo: {
    type: Object,
    default: () => ({ incoming: false, outgoing: false }),
  },
  messages: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['retry']);
const { t } = useI18n();

const EDGE_MESSAGE_COUNT = 3;
const REVEAL_BATCH_SIZE = 6;
const revealedMiddleCount = ref(0);

const allMessages = computed(() => {
  return useCamelCase(props.messages, {
    deep: true,
    stopPaths: ['content_attributes.translations'],
  });
});

// A conversation switched from chat to email (Conversations::SwitchToEmailService)
// keeps its old chat messages in the same thread — each message carries its own
// inbox_id from when it was actually sent, so render every message against the
// inbox it belongs to rather than the conversation's current (possibly since
// changed) inbox. Falls back to the conversation-level flag if a message's own
// inbox isn't resolvable (e.g. hasn't loaded into the inboxes store yet).
const inboxGetter = useMapGetter('inboxes/getInbox');
const isMessageFromEmailInbox = message => {
  const inbox = inboxGetter.value(message?.inboxId);
  if (!inbox) return props.isAnEmailChannel;
  return (inbox.channel_type || inbox.channelType) === INBOX_TYPES.EMAIL;
};

const shouldCollapseMiddle = computed(
  () =>
    props.isAnEmailChannel && allMessages.value.length > EDGE_MESSAGE_COUNT * 2
);

const middleMessages = computed(() => {
  if (!shouldCollapseMiddle.value) {
    return [];
  }

  return allMessages.value.slice(
    EDGE_MESSAGE_COUNT,
    allMessages.value.length - EDGE_MESSAGE_COUNT
  );
});

const remainingMiddleCount = computed(() =>
  Math.max(0, middleMessages.value.length - revealedMiddleCount.value)
);

const displayItems = computed(() => {
  if (!shouldCollapseMiddle.value) {
    return allMessages.value.map((message, index) => ({
      type: 'message',
      message,
      index,
    }));
  }

  const firstMessages = allMessages.value
    .slice(0, EDGE_MESSAGE_COUNT)
    .map((message, index) => ({ type: 'message', message, index }));
  const revealedMessages = middleMessages.value
    .slice(0, revealedMiddleCount.value)
    .map((message, index) => ({
      type: 'message',
      message,
      index: EDGE_MESSAGE_COUNT + index,
    }));
  const lastStart = allMessages.value.length - EDGE_MESSAGE_COUNT;
  const lastMessages = allMessages.value
    .slice(lastStart)
    .map((message, index) => ({
      type: 'message',
      message,
      index: lastStart + index,
    }));
  const placeholder =
    remainingMiddleCount.value > 0
      ? [
          {
            type: 'middle-placeholder',
            id: `middle-placeholder-${remainingMiddleCount.value}`,
            count: remainingMiddleCount.value,
          },
        ]
      : [];

  return [
    ...firstMessages,
    ...revealedMessages,
    ...placeholder,
    ...lastMessages,
  ];
});

watch(
  () => props.messages.map(message => message.id).join(','),
  () => {
    revealedMiddleCount.value = 0;
  }
);

const revealMiddleMessages = () => {
  revealedMiddleCount.value = Math.min(
    middleMessages.value.length,
    revealedMiddleCount.value + REVEAL_BATCH_SIZE
  );
};

const currentChat = useMapGetter('getSelectedChat');

// Cache for fetched reply messages to avoid duplicate API calls
const fetchedReplyMessages = reactive(new Map());

/**
 * Fetches a specific message from the API by trying to get messages around it
 * @param {number} messageId - The ID of the message to fetch
 * @param {number} conversationId - The ID of the conversation
 * @returns {Promise<Object|null>} - The fetched message or null if not found/error
 */
const fetchReplyMessage = async (messageId, conversationId) => {
  // Return cached result if already fetched
  if (fetchedReplyMessages.has(messageId)) {
    return fetchedReplyMessages.get(messageId);
  }

  try {
    const response = await MessageApi.getPreviousMessages({
      conversationId,
      before: messageId + 100,
      after: messageId - 100,
    });

    const messages = response.data?.payload || [];
    const targetMessage = messages.find(msg => msg.id === messageId);

    if (targetMessage) {
      const camelCaseMessage = useCamelCase(targetMessage);
      fetchedReplyMessages.set(messageId, camelCaseMessage);
      return camelCaseMessage;
    }

    // Cache null result to avoid repeated API calls
    fetchedReplyMessages.set(messageId, null);
    return null;
  } catch (error) {
    fetchedReplyMessages.set(messageId, null);
    return null;
  }
};

/**
 * Determines if a message should be grouped with the next message
 * @param {Number} index - Index of the current message
 * @param {Array} searchList - Array of messages to check
 * @returns {Boolean} - Whether the message should be grouped with next
 */
const shouldGroupWithNext = (index, searchList) => {
  if (index === searchList.length - 1) return false;

  const current = searchList[index];
  const next = searchList[index + 1];

  if (next.status === 'failed') return false;

  const nextSenderId = next.senderId ?? next.sender?.id;
  const currentSenderId = current.senderId ?? current.sender?.id;
  const hasSameSender = nextSenderId === currentSenderId;

  const nextMessageType = next.messageType;
  const currentMessageType = current.messageType;

  const areBothTemplates =
    nextMessageType === MESSAGE_TYPES.TEMPLATE &&
    currentMessageType === MESSAGE_TYPES.TEMPLATE;

  if (!hasSameSender || areBothTemplates) return false;

  if (currentMessageType !== nextMessageType) return false;

  // Check if messages are in the same minute by rounding down to nearest minute
  return Math.floor(next.createdAt / 60) === Math.floor(current.createdAt / 60);
};

/**
 * Gets the message that was replied to
 * @param {Object} parentMessage - The message containing the reply reference
 * @returns {Object|null} - The message being replied to, or null if not found
 */
const getInReplyToMessage = parentMessage => {
  if (!parentMessage) return null;

  const inReplyToMessageId =
    parentMessage.contentAttributes?.inReplyTo ??
    parentMessage.content_attributes?.in_reply_to;

  if (!inReplyToMessageId) return null;

  // Try to find in current messages first
  let replyMessage = props.messages?.find(msg => msg.id === inReplyToMessageId);

  // Then try store messages
  if (!replyMessage && currentChat.value?.messages) {
    replyMessage = currentChat.value.messages.find(
      msg => msg.id === inReplyToMessageId
    );
  }

  // Then check fetch cache
  if (!replyMessage && fetchedReplyMessages.has(inReplyToMessageId)) {
    replyMessage = fetchedReplyMessages.get(inReplyToMessageId);
  }

  // If still not found and we have conversation context, fetch it
  if (!replyMessage && currentChat.value?.id) {
    fetchReplyMessage(inReplyToMessageId, currentChat.value.id);
    return null; // Let UI handle loading state
  }

  return replyMessage ? useCamelCase(replyMessage) : null;
};
</script>

<template>
  <ul class="bg-n-surface-1" :class="isAnEmailChannel ? 'px-0' : 'px-4'">
    <slot name="beforeAll" />
    <template v-for="item in displayItems" :key="item.message?.id || item.id">
      <slot
        v-if="
          item.type === 'message' &&
          firstUnreadId &&
          item.message.id === firstUnreadId
        "
        name="unreadBadge"
      />
      <Message
        v-if="item.type === 'message'"
        v-bind="item.message"
        :is-email-inbox="isMessageFromEmailInbox(item.message)"
        :in-reply-to="getInReplyToMessage(item.message)"
        :group-with-next="shouldGroupWithNext(item.index, allMessages)"
        :force-email-expanded="isAnEmailChannel"
        :inbox-supports-reply-to="inboxSupportsReplyTo"
        :current-user-id="currentUserId"
        data-clarity-mask="True"
        @retry="emit('retry', item.message)"
      />
      <li v-else class="my-4 flex list-none items-center justify-center">
        <button
          type="button"
          class="inline-flex h-8 items-center gap-2 rounded-full border border-fd-border bg-fd-surface px-4 text-xs font-semibold text-fd-primary shadow-sm hover:bg-fd-blueSoft"
          @click="revealMiddleMessages"
        >
          <span class="i-lucide-messages-square size-3.5" />
          {{
            t('CHAT_LIST.FRESHDESK_DETAIL.MIDDLE_CONVERSATIONS', {
              count: item.count,
            })
          }}
        </button>
      </li>
    </template>
    <slot name="after" />
  </ul>
</template>
