<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import { getLastMessage } from 'dashboard/helper/conversationHelper';
import { useMessageFormatter } from 'shared/composables/useMessageFormatter';
import { MESSAGE_TYPE } from 'shared/constants/messages';
import Avatar from 'next/avatar/Avatar.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { dynamicTimeStrict } from 'shared/helpers/timeHelper';
import { shortenAgentName } from 'shared/helpers/agentNameHelper';
import UnreadBadge from 'dashboard/components-next/Conversation/ConversationCard/UnreadBadge.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';

const props = defineProps({
  chat: { type: Object, required: true },
  currentContact: { type: Object, required: true },
  assignee: { type: Object, default: () => ({}) },
  inbox: { type: Object, default: () => ({}) },
  selected: { type: Boolean, default: false },
  isActiveChat: { type: Boolean, default: false },
  hideThumbnail: { type: Boolean, default: false },
  compact: { type: Boolean, default: false },
});

const emit = defineEmits([
  'click',
  'contextmenu',
  'assignAgent',
  'assignPriority',
  'updateConversationStatus',
  'selectConversation',
  'deSelectConversation',
]);

const { t } = useI18n();
const store = useStore();
const { getPlainText } = useMessageFormatter();
const hovered = ref(false);

const unreadCount = computed(() => props.chat.unread_count);
const hasUnread = computed(() => unreadCount.value > 0);
const lastMessageInChat = computed(() => getLastMessage(props.chat));
const displayId = computed(() => {
  const additionalAttributes =
    props.chat.additional_attributes || props.chat.additionalAttributes || {};
  return (
    additionalAttributes.ticket_number || props.chat.display_id || props.chat.id
  );
});
const createdTimestamp = computed(
  () => props.chat.created_at || props.chat.timestamp
);
const isAgentBotAssignee = computed(
  () => props.chat?.meta?.assignee_type === 'AgentBot'
);

const subject = computed(() => {
  const additionalAttributes =
    props.chat.additional_attributes || props.chat.additionalAttributes || {};
  const emailSubject =
    additionalAttributes.mail_subject || additionalAttributes.mailSubject;
  return getPlainText(
    emailSubject ||
      lastMessageInChat.value?.content ||
      t('CHAT_LIST.NO_CONTENT')
  );
});

const priorityOptions = computed(() => [
  { key: '', label: t('CONVERSATION.PRIORITY.OPTIONS.NONE') },
  { key: 'low', label: t('CONVERSATION.PRIORITY.OPTIONS.LOW') },
  { key: 'medium', label: t('CONVERSATION.PRIORITY.OPTIONS.MEDIUM') },
  { key: 'high', label: t('CONVERSATION.PRIORITY.OPTIONS.HIGH') },
  { key: 'urgent', label: t('CONVERSATION.PRIORITY.OPTIONS.URGENT') },
]);

const priorityLabel = computed(() => {
  const selected = priorityOptions.value.find(
    item => item.key === (props.chat.priority || '')
  );
  return selected?.label || t('CONVERSATION.PRIORITY.OPTIONS.NONE');
});

const priorityDotClass = computed(() => {
  if (props.chat.priority === 'urgent') return 'bg-fd-red';
  if (['medium', 'high'].includes(props.chat.priority)) return 'bg-fd-amber';
  return 'bg-fd-green';
});

const statusOptions = computed(() => [
  { key: 'open', label: t('CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.open.TEXT') },
  {
    key: 'pending',
    label: t('CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.pending.TEXT'),
  },
  {
    key: 'resolved',
    label: t('CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.resolved.TEXT'),
  },
]);

const currentStatusLabel = computed(() => {
  const currentStatus = statusOptions.value.find(
    item => item.key === props.chat.status
  );
  return currentStatus?.label || props.chat.status;
});

// An agent has replied at least once when Chatwoot has stamped the first reply.
const hasAgentReplied = computed(() =>
  Boolean(props.chat.first_reply_created_at)
);
const isAssigned = computed(() => Boolean(props.assignee?.id));
const lastMessageIsIncoming = computed(
  () => lastMessageInChat.value?.message_type === MESSAGE_TYPE.INCOMING
);

// Freshdesk "New": open, nobody assigned, and no agent has replied yet.
const isNew = computed(
  () =>
    props.chat.status === 'open' && !isAssigned.value && !hasAgentReplied.value
);

// Freshdesk "Customer responded": the latest message is from the customer and
// an agent had already replied earlier in the thread.
const customerResponded = computed(
  () => lastMessageIsIncoming.value && hasAgentReplied.value
);

// Meta line under the subject: when the customer has replied to us, surface
// "Customer responded <time> ago" using the latest inbound message time;
// otherwise fall back to when the ticket was created.
const activityMeta = computed(() => {
  if (customerResponded.value) {
    return {
      label: t('CHAT_LIST.FRESHDESK_CARD.STATUS.CUSTOMER_RESPONDED'),
      timeAgo: dynamicTimeStrict(
        lastMessageInChat.value?.created_at || createdTimestamp.value
      ),
    };
  }
  return {
    label: t('CHAT_LIST.FRESHDESK_CARD.CREATED'),
    timeAgo: dynamicTimeStrict(createdTimestamp.value),
  };
});

const statusPills = computed(() => {
  const pills = [];

  if (isNew.value) {
    pills.push({
      key: 'new',
      label: t('CHAT_LIST.FRESHDESK_CARD.STATUS.NEW'),
      class: 'bg-fd-greenSoft text-fd-green',
    });
  }

  if (customerResponded.value) {
    pills.push({
      key: 'customer-responded',
      label: t('CHAT_LIST.FRESHDESK_CARD.STATUS.CUSTOMER_RESPONDED'),
      class: 'bg-fd-blueSoft text-fd-blue',
    });
  }

  if (!pills.length) {
    pills.push({
      key: props.chat.status,
      label: currentStatusLabel.value,
      class: 'bg-n-slate-3 text-n-slate-11',
    });
  }
  return pills;
});

const assignableAgents = computed(() => {
  const agents = store.getters['inboxAssignableAgents/getAssignableAgents'](
    props.inbox.id
  );
  return [
    {
      confirmed: true,
      name: t('CHAT_LIST.FRESHDESK_CARD.UNASSIGNED'),
      id: null,
      role: 'agent',
      account_id: 0,
      email: '',
    },
    ...agents,
  ];
});

const assigneeId = computed(() => props.assignee.id || '');
const assigneeLabel = computed(() =>
  props.assignee.name
    ? shortenAgentName(props.assignee.name)
    : t('CHAT_LIST.FRESHDESK_CARD.UNASSIGNED')
);

const onThumbnailHover = () => {
  hovered.value = !props.hideThumbnail;
};

const onThumbnailLeave = () => {
  hovered.value = false;
};

const onSelectConversation = checked => {
  if (checked) {
    emit('selectConversation', props.chat.id, props.inbox.id);
  } else {
    emit('deSelectConversation', props.chat.id, props.inbox.id);
  }
};

const selectedModel = computed({
  get: () => props.selected,
  set: value => onSelectConversation(value),
});

const onAssignAgent = event => {
  const selectedId = event.target.value;
  const agent = assignableAgents.value.find(
    item => String(item.id ?? '') === selectedId
  );
  if (agent) emit('assignAgent', agent);
};

const onAssignPriority = event => {
  emit('assignPriority', event.target.value || null);
};

const onUpdateStatus = event => {
  emit('updateConversationStatus', event.target.value, null);
};

const fetchAssignableAgents = () => {
  if (props.inbox.id) {
    store.dispatch('inboxAssignableAgents/fetch', [props.inbox.id]);
  }
};

onMounted(fetchAssignableAgents);

watch(
  () => props.chat.id,
  () => {
    hovered.value = false;
  }
);

watch(() => props.inbox.id, fetchAssignableAgents);
</script>

<template>
  <div
    class="relative flex flex-grow-0 flex-shrink-0 w-auto max-w-full px-3 py-1 cursor-pointer conversation bg-fd-background group hover:z-[1]"
    :class="{
      'active animate-card-select': isActiveChat,
      selected: selected,
      'px-1': compact,
    }"
    @click="$emit('click', $event)"
    @contextmenu="$emit('contextmenu', $event)"
  >
    <div
      class="grid w-full grid-cols-[auto_minmax(0,1fr)] items-center gap-x-4 gap-y-2 border border-fd-border bg-fd-surface px-3 py-3 transition-colors hover:border-fd-primary/40 sm:grid-cols-[auto_minmax(0,1fr)_minmax(11rem,14rem)]"
      :class="{
        'ring-2 ring-fd-primary/30': isActiveChat,
        'border-fd-primary bg-fd-surface': selected,
      }"
    >
      <div
        class="grid grid-cols-[auto_2.5rem] items-center gap-3"
        @mouseenter="onThumbnailHover"
        @mouseleave="onThumbnailLeave"
      >
        <div @click.stop>
          <Checkbox v-model="selectedModel" />
        </div>
        <Avatar
          v-if="!hideThumbnail"
          :name="currentContact.name"
          :src="currentContact.thumbnail"
          :size="40"
          :status="currentContact.availability_status"
          hide-offline-status
        />
      </div>

      <div class="flex min-w-0 flex-col gap-1.5">
        <div class="flex flex-wrap items-center gap-1.5">
          <span
            v-for="pill in statusPills"
            :key="pill.key"
            class="rounded px-1.5 py-0.5 text-xxs font-medium leading-4"
            :class="pill.class"
          >
            {{ pill.label }}
          </span>
          <UnreadBadge v-if="hasUnread" :count="unreadCount" />
        </div>

        <h4
          class="conversation--user m-0 truncate text-[13px] font-semibold leading-5 text-fd-text"
        >
          {{ subject }}
          <span class="font-medium text-fd-muted">
            {{ $t('CHAT_LIST.FRESHDESK_CARD.TICKET_ID', { id: displayId }) }}
          </span>
        </h4>

        <div
          class="flex min-w-0 flex-wrap items-center gap-x-1.5 gap-y-1 text-xs leading-5 text-fd-text"
        >
          <span
            class="inline-flex min-w-0 max-w-full items-center gap-1 truncate"
          >
            <Icon icon="i-lucide-mail" class="size-3 shrink-0 text-fd-muted" />
            <span class="truncate">{{ currentContact.name }}</span>
          </span>
          <span class="text-fd-muted">
            {{ $t('CHAT_LIST.FRESHDESK_CARD.SEPARATOR') }}
          </span>
          <span class="inline-flex items-center gap-1 text-fd-muted">
            {{ activityMeta.label }} {{ activityMeta.timeAgo }}
          </span>
        </div>
      </div>

      <div
        class="col-start-2 grid min-w-0 shrink-0 gap-1.5 text-xs leading-5 text-fd-text sm:col-start-auto sm:gap-2"
        @click.stop
      >
        <label class="relative inline-flex min-w-0 items-center gap-1.5">
          <span class="sr-only">{{
            $t('CHAT_LIST.FRESHDESK_CARD.PRIORITY')
          }}</span>
          <span class="size-1.5 rounded-sm" :class="priorityDotClass" />
          <span class="truncate">{{ priorityLabel }}</span>
          <Icon icon="i-lucide-chevron-down" class="size-3 shrink-0" />
          <select
            class="absolute inset-0 cursor-pointer opacity-0"
            :value="chat.priority || ''"
            @change="onAssignPriority"
          >
            <option
              v-for="option in priorityOptions"
              :key="option.key"
              :value="option.key"
            >
              {{ option.label }}
            </option>
          </select>
        </label>

        <label class="relative inline-flex min-w-0 items-center gap-1.5">
          <Icon
            :icon="isAgentBotAssignee ? 'i-lucide-bot' : 'i-lucide-user-round'"
            class="size-3 shrink-0 text-fd-muted"
          />
          <span class="truncate">{{ assigneeLabel }}</span>
          <Icon icon="i-lucide-chevron-down" class="size-3 shrink-0" />
          <select
            class="absolute inset-0 cursor-pointer opacity-0"
            :value="assigneeId"
            @change="onAssignAgent"
          >
            <option
              v-for="agent in assignableAgents"
              :key="agent.id ?? 'none'"
              :value="agent.id ?? ''"
            >
              {{ agent.name }}
            </option>
          </select>
        </label>

        <label class="relative inline-flex min-w-0 items-center gap-1.5">
          <span class="sr-only">
            {{ $t('CHAT_LIST.FRESHDESK_CARD.STATUS_LABEL') }}
          </span>
          <Icon
            icon="i-lucide-activity"
            class="size-3 shrink-0 text-fd-muted"
          />
          <span class="truncate">{{ currentStatusLabel }}</span>
          <Icon icon="i-lucide-chevron-down" class="size-3 shrink-0" />
          <select
            class="absolute inset-0 cursor-pointer opacity-0"
            :value="chat.status"
            @change="onUpdateStatus"
          >
            <option
              v-for="option in statusOptions"
              :key="option.key"
              :value="option.key"
            >
              {{ option.label }}
            </option>
          </select>
        </label>
      </div>
    </div>
  </div>
</template>
