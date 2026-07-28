<script setup>
import { computed } from 'vue';
import { useMapGetter } from 'dashboard/composables/store.js';

import SearchResultSection from './SearchResultSection.vue';
import SearchResultConversationItem from './SearchResultConversationItem.vue';

const props = defineProps({
  conversations: {
    type: Array,
    default: () => [],
  },
  query: {
    type: String,
    default: '',
  },
  isFetching: {
    type: Boolean,
    default: false,
  },
  showTitle: {
    type: Boolean,
    default: true,
  },
});

const accountId = useMapGetter('getCurrentAccountId');

const conversationsWithSubject = computed(() => {
  return props.conversations.map(conversation => ({
    ...conversation,
    mailSubject: conversation.additionalAttributes?.mailSubject || '',
    // conversation.id here is already display_id (see the search jbuilder),
    // so the only real fallback left is the Freshdesk-style ticket_number —
    // same precedence as ConversationCard.vue's displayId computed.
    ticketNumber:
      conversation.additionalAttributes?.ticketNumber || conversation.id,
  }));
});
</script>

<template>
  <SearchResultSection
    :title="$t('SEARCH.SECTION.CONVERSATIONS')"
    :empty="!conversations.length"
    :query="query"
    :show-title="showTitle"
    :is-fetching="isFetching"
  >
    <ul v-if="conversations.length" class="space-y-4 list-none">
      <li
        v-for="conversation in conversationsWithSubject"
        :key="conversation.id"
      >
        <SearchResultConversationItem
          :id="conversation.id"
          :ticket-number="conversation.ticketNumber"
          :name="conversation.contact.name"
          :email="conversation.contact.email"
          :account-id="accountId"
          :inbox="conversation.inbox"
          :created-at="conversation.createdAt"
          :email-subject="conversation.mailSubject"
          :message-preview="conversation.message?.content"
        />
      </li>
    </ul>
  </SearchResultSection>
</template>
