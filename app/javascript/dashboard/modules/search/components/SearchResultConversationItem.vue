<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { frontendURL } from 'dashboard/helper/URLHelper.js';
import { dynamicTime } from 'shared/helpers/timeHelper';
import { useInbox } from 'dashboard/composables/useInbox';
import { getInboxIconByType } from 'dashboard/helper/inbox';
import { useMessageFormatter } from 'shared/composables/useMessageFormatter';

import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  id: {
    type: Number,
    default: 0,
  },
  ticketNumber: {
    type: [String, Number],
    default: 0,
  },
  inbox: {
    type: Object,
    default: () => ({}),
  },
  name: {
    type: String,
    default: '',
  },
  email: {
    type: String,
    default: '',
  },
  accountId: {
    type: [String, Number],
    default: '',
  },
  createdAt: {
    type: [String, Date, Number],
    default: '',
  },
  messageId: {
    type: Number,
    default: 0,
  },
  emailSubject: {
    type: String,
    default: '',
  },
  messagePreview: {
    type: String,
    default: '',
  },
});

const { t } = useI18n();
const { getPlainText } = useMessageFormatter();
const { inbox } = useInbox(props.inbox?.id);

const navigateTo = computed(() => {
  const params = {};
  if (props.messageId) {
    params.messageId = props.messageId;
  }
  return frontendURL(
    `accounts/${props.accountId}/conversations/${props.id}`,
    params
  );
});

const createdAtTime = computed(() => {
  if (!props.createdAt) return '';
  return dynamicTime(props.createdAt);
});

// Same precedence as ConversationCard.vue's subject computed: the ticket's
// locked-in email subject first, falling back to the first message so a
// live-chat result (no subject) still shows something scannable.
const subject = computed(() => {
  if (props.emailSubject) return props.emailSubject;
  if (props.messagePreview) return getPlainText(props.messagePreview);
  return t('SEARCH.NO_SUBJECT');
});

const inboxIcon = computed(() => {
  if (!inbox.value) return null;
  const { channelType, medium } = inbox.value;
  return getInboxIconByType(channelType, medium);
});
</script>

<template>
  <router-link :to="navigateTo">
    <div
      class="flex items-start gap-3 rounded-lg border border-fd-border bg-fd-surface px-4 py-3 transition-colors hover:border-fd-primary/40 hover:bg-fd-background"
    >
      <Avatar
        :name="name || email"
        :size="36"
        rounded-full
        class="mt-0.5 flex-shrink-0"
      />
      <div class="min-w-0 flex-1">
        <div class="flex items-start justify-between gap-3">
          <h5
            class="m-0 min-w-0 truncate text-[13px] font-semibold leading-5 text-fd-text"
          >
            {{ subject }}
            <span class="font-medium text-fd-muted">
              {{
                $t('CHAT_LIST.FRESHDESK_CARD.TICKET_ID', {
                  id: ticketNumber || id,
                })
              }}
            </span>
          </h5>
          <span
            v-if="createdAtTime"
            class="shrink-0 text-xs leading-5 text-fd-muted"
          >
            {{ createdAtTime }}
          </span>
        </div>
        <div
          class="mt-1 flex min-w-0 flex-wrap items-center gap-x-1.5 gap-y-1 text-xs leading-5 text-fd-muted"
        >
          <span
            v-if="inboxIcon"
            class="flex size-4 shrink-0 items-center justify-center rounded-full bg-fd-background"
          >
            <Icon :icon="inboxIcon" class="size-2.5 shrink-0" />
          </span>
          <span v-if="name" class="min-w-0 truncate text-fd-text">
            {{ name }}
          </span>
          <template v-if="name && email">
            <span>{{ $t('CHAT_LIST.FRESHDESK_CARD.SEPARATOR') }}</span>
          </template>
          <span v-if="email" class="min-w-0 truncate">
            {{ email }}
          </span>
        </div>
      </div>
      <slot />
    </div>
  </router-link>
</template>
