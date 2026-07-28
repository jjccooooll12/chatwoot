<script setup>
import { computed, onMounted, watch } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import Avatar from 'next/avatar/Avatar.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { frontendURL } from 'dashboard/helper/URLHelper';
import { dateFormat } from 'shared/helpers/timeHelper';
import { INBOX_TYPES } from 'dashboard/helper/inbox';

const props = defineProps({
  chat: { type: Object, required: true },
});

const { t } = useI18n();
const store = useStore();
const route = useRoute();

const accountId = computed(() => route.params.accountId);
const contact = computed(() => props.chat?.meta?.sender || {});
const contactId = computed(() => contact.value?.id);

const conversationsGetter = useMapGetter(
  'contactConversations/getContactConversation'
);
// The contactConversations module is a one-off snapshot fetched when the
// panel mounts, so it goes stale the moment an agent changes a property
// (status, priority, assignee, ...) on any of these tickets. The main
// conversations store IS kept live (sockets + every property-update action
// commit straight into it), so overlay it here to reflect changes instantly
// without a manual refetch.
const liveConversationGetter = useMapGetter('getConversationById');
const recentConversations = computed(() => {
  const list = contactId.value
    ? conversationsGetter.value(contactId.value) || []
    : [];
  const merged = list.map(conversation => {
    const live = liveConversationGetter.value(conversation.id);
    return live ? { ...conversation, ...live } : conversation;
  });
  return merged
    .sort((a, b) => (b.created_at || 0) - (a.created_at || 0))
    .slice(0, 6);
});

const contactUrl = computed(() =>
  frontendURL(`accounts/${accountId.value}/contacts/${contactId.value}`)
);
const conversationUrl = id =>
  frontendURL(`accounts/${accountId.value}/conversations/${id}`);

const channelIconFor = conversation => {
  const inbox = store.getters['inboxes/getInbox'](conversation.inbox_id);
  const channelType = inbox?.channel_type || inbox?.channelType;
  return channelType === INBOX_TYPES.WEB
    ? 'i-lucide-message-circle'
    : 'i-lucide-mail';
};
const subjectOf = conversation => {
  const attrs = conversation.additional_attributes || {};
  return (
    attrs.mail_subject ||
    conversation.messages?.[0]?.content ||
    t('CHAT_LIST.NO_CONTENT')
  );
};
const ticketNumberOf = conversation => {
  const attrs = conversation.additional_attributes || {};
  return (
    conversation.ticket_number ||
    attrs.ticket_number ||
    conversation.display_id ||
    conversation.id
  );
};
const statusLabelMap = computed(() => ({
  open: t('CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.open.TEXT'),
  resolved: t('CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.resolved.TEXT'),
  pending: t('CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.pending.TEXT'),
  snoozed: t('CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.snoozed.TEXT'),
}));
const statusLabel = conversation =>
  statusLabelMap.value[conversation.status] || conversation.status;
const timeLabel = conversation =>
  conversation.created_at
    ? dateFormat(conversation.created_at, 'd MMM yyyy, h:mm a')
    : '';

const fetchConversations = () => {
  if (contactId.value) {
    store.dispatch('contactConversations/get', contactId.value);
  }
};
onMounted(fetchConversations);
watch(contactId, fetchConversations);
</script>

<template>
  <aside
    class="hidden w-[276px] shrink-0 overflow-y-auto border-l border-fd-border bg-fd-surface xl:block"
  >
    <div class="border-b border-fd-border px-3 py-4">
      <div class="mb-3 flex items-center justify-between">
        <span
          class="text-xxs font-semibold uppercase tracking-wide text-fd-muted"
        >
          {{ t('CHAT_LIST.FRESHDESK_DETAIL.CONTACT_INFO') }}
        </span>
      </div>
      <div class="flex items-center gap-2">
        <Avatar :name="contact.name" :src="contact.thumbnail" :size="36" />
        <div class="min-w-0">
          <p class="m-0 truncate text-sm font-semibold text-fd-text">
            {{ contact.name }}
          </p>
          <a
            v-if="contact.email"
            :href="`mailto:${contact.email}`"
            class="m-0 block truncate text-xs text-fd-primary hover:underline"
          >
            {{ contact.email }}
          </a>
        </div>
      </div>
      <a
        v-if="contactId"
        :href="contactUrl"
        class="mt-3 inline-flex items-center gap-1 text-xs font-medium text-fd-primary hover:underline"
      >
        <Icon icon="i-lucide-external-link" class="size-3" />
        {{ t('CHAT_LIST.FRESHDESK_DETAIL.VIEW_MORE_INFO') }}
      </a>
    </div>

    <div class="px-3 py-4">
      <p class="mb-3 text-xs font-semibold text-fd-text">
        {{ t('CHAT_LIST.FRESHDESK_DETAIL.RECENT_TIMELINE') }}
      </p>
      <p v-if="!recentConversations.length" class="text-xs text-fd-muted">
        {{ t('CHAT_LIST.FRESHDESK_DETAIL.NO_TIMELINE') }}
      </p>
      <ul v-else class="m-0 flex list-none flex-col gap-4 p-0">
        <li
          v-for="conversation in recentConversations"
          :key="conversation.id"
          class="flex gap-2"
        >
          <Icon
            :icon="channelIconFor(conversation)"
            class="mt-0.5 size-3.5 shrink-0 text-fd-muted"
          />
          <div class="min-w-0 flex-1">
            <a
              :href="conversationUrl(conversation.id)"
              class="m-0 line-clamp-2 text-xs font-medium leading-4 text-fd-text hover:text-fd-primary"
            >
              {{ subjectOf(conversation) }}
            </a>
            <p class="m-0 select-text text-xs font-medium text-fd-primary">
              {{ `#${ticketNumberOf(conversation)}` }}
            </p>
            <p class="m-0 mt-0.5 select-text text-xs text-fd-muted">
              {{ timeLabel(conversation) }}
            </p>
            <p class="m-0 select-text text-xs text-fd-muted">
              {{
                `${t('CHAT_LIST.FRESHDESK_DETAIL.STATUS_LINE')}: ${statusLabel(
                  conversation
                )}`
              }}
            </p>
          </div>
        </li>
      </ul>
    </div>
  </aside>
</template>
