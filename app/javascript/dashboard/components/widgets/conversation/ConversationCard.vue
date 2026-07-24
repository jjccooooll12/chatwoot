<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import { getLastMessage } from 'dashboard/helper/conversationHelper';
import { useMessageFormatter } from 'shared/composables/useMessageFormatter';
import { MESSAGE_TYPE } from 'shared/constants/messages';
import Avatar from 'next/avatar/Avatar.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import MessagePreview from './MessagePreview.vue';
import InboxName from '../InboxName.vue';
import TimeAgo from 'dashboard/components/ui/TimeAgo.vue';
import UnreadBadge from 'dashboard/components-next/Conversation/ConversationCard/UnreadBadge.vue';
import SLACardLabel from './components/SLACardLabel.vue';
import VoiceCallStatus from './VoiceCallStatus.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';

const props = defineProps({
  chat: { type: Object, required: true },
  currentContact: { type: Object, required: true },
  assignee: { type: Object, default: () => ({}) },
  inbox: { type: Object, default: () => ({}) },
  selected: { type: Boolean, default: false },
  isActiveChat: { type: Boolean, default: false },
  showInboxName: { type: Boolean, default: false },
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
const displayId = computed(() => props.chat.display_id || props.chat.id);
const createdTimestamp = computed(
  () => props.chat.created_at || props.chat.timestamp
);
const appliedSLA = computed(() => props.chat?.applied_sla);
const isAgentBotAssignee = computed(
  () => props.chat?.meta?.assignee_type === 'AgentBot'
);

const voiceCallData = computed(() => {
  const last = lastMessageInChat.value;
  if (last?.content_type !== 'voice_call' || !last.call) {
    return { status: null, direction: null };
  }
  return {
    status: last.call.status,
    direction: last.call.direction === 'outgoing' ? 'outbound' : 'inbound',
  };
});

const hasSlaPolicyId = computed(
  () => props.chat?.applied_sla?.id && !props.currentContact?.blocked
);

const hasSlaMiss = computed(() => {
  const status = appliedSLA.value?.sla_status;
  return status === 'missed' || status === 'active_with_misses';
});

const messagePreviewClass = computed(() => {
  return [
    hasUnread.value ? 'font-medium text-n-slate-12' : 'text-n-slate-11',
    !props.compact && hasUnread.value ? 'ltr:pr-4 rtl:pl-4' : '',
    props.compact && hasUnread.value ? 'ltr:pr-6 rtl:pl-6' : '',
  ];
});

const subject = computed(() => {
  const customAttributes =
    props.chat.custom_attributes || props.chat.customAttributes || {};
  const emailSubject = customAttributes.email?.subject;
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
  ...(props.chat.status === 'snoozed'
    ? [
        {
          key: 'snoozed',
          label: t('CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.snoozed.TEXT'),
        },
      ]
    : []),
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

const statusPills = computed(() => {
  const pills = [];
  if (hasSlaMiss.value) {
    pills.push({
      key: 'overdue',
      label: t('CHAT_LIST.FRESHDESK_CARD.STATUS.OVERDUE'),
      class: 'bg-fd-redSoft text-fd-red',
    });
  }

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
const assigneeLabel = computed(() => {
  const group = props.inbox.name || t('CHAT_LIST.FRESHDESK_CARD.ANY_GROUP');
  const agent = props.assignee.name || t('CHAT_LIST.FRESHDESK_CARD.UNASSIGNED');
  return `${group} / ${agent}`;
});

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
    class="relative flex flex-grow-0 flex-shrink-0 w-auto max-w-full px-3 py-2 cursor-pointer conversation bg-fd-background group hover:z-[1]"
    :class="{
      'active animate-card-select': isActiveChat,
      selected: selected,
      'px-1': compact,
    }"
    @click="$emit('click', $event)"
    @contextmenu="$emit('contextmenu', $event)"
  >
    <div
      class="grid w-full grid-cols-[auto_1fr_auto] items-start gap-3 rounded-xl border border-fd-border bg-fd-surface p-3 shadow-sm transition-colors hover:border-fd-primary/40"
      :class="{
        'ring-2 ring-fd-primary/30': isActiveChat,
        'border-fd-primary bg-fd-surface': selected,
      }"
    >
      <div
        class="grid grid-cols-[auto_2rem] gap-2"
        @mouseenter="onThumbnailHover"
        @mouseleave="onThumbnailLeave"
      >
        <div class="pt-2" @click.stop>
          <Checkbox v-model="selectedModel" />
        </div>
        <Avatar
          v-if="!hideThumbnail"
          :name="currentContact.name"
          :src="currentContact.thumbnail"
          :size="32"
          :status="currentContact.availability_status"
          hide-offline-status
        />
      </div>

      <div class="flex min-w-0 flex-col gap-2">
        <div class="flex flex-wrap gap-1.5">
          <span
            v-for="pill in statusPills"
            :key="pill.key"
            class="rounded-md px-2 py-1 text-xxs font-semibold uppercase leading-none"
            :class="pill.class"
          >
            {{ pill.label }}
          </span>
          <UnreadBadge v-if="hasUnread" :count="unreadCount" />
        </div>

        <h4
          class="conversation--user m-0 line-clamp-2 text-[15px] font-semibold leading-5 text-fd-text"
        >
          {{ subject }}
          {{ $t('CHAT_LIST.FRESHDESK_CARD.TICKET_ID', { id: displayId }) }}
        </h4>

        <div
          class="flex min-w-0 flex-wrap items-center gap-x-2 gap-y-1 text-xs text-fd-muted"
        >
          <span
            v-if="showInboxName"
            class="inline-flex min-w-0 max-w-full items-center gap-1"
          >
            <InboxName :inbox="inbox" class="min-w-0" />
          </span>
          <span
            v-else
            class="inline-flex min-w-0 max-w-full items-center gap-1 truncate"
          >
            <Icon icon="i-lucide-mail" class="size-3.5 shrink-0" />
            <span class="truncate">{{ currentContact.name }}</span>
          </span>
          <span class="text-n-slate-8">
            {{ $t('CHAT_LIST.FRESHDESK_CARD.SEPARATOR') }}
          </span>
          <span class="inline-flex items-center gap-1">
            {{ $t('CHAT_LIST.FRESHDESK_CARD.CREATED') }}
            <TimeAgo
              :last-activity-timestamp="createdTimestamp"
              :created-at-timestamp="createdTimestamp"
              :conversation-id="chat.id"
            />
          </span>
          <span v-if="hasSlaPolicyId" class="inline-flex items-center gap-1">
            <span class="text-n-slate-8">
              {{ $t('CHAT_LIST.FRESHDESK_CARD.SEPARATOR') }}
            </span>
            <SLACardLabel :chat="chat" />
          </span>
        </div>

        <VoiceCallStatus
          v-if="voiceCallData.status"
          key="voice-status-row"
          :status="voiceCallData.status"
          :direction="voiceCallData.direction"
          :message-preview-class="messagePreviewClass"
        />
        <MessagePreview
          v-else-if="lastMessageInChat"
          key="message-preview"
          :message="lastMessageInChat"
          class="m-0 min-w-0 text-sm leading-5"
          :class="messagePreviewClass"
        />
        <p
          v-else
          key="no-messages"
          class="m-0 flex min-w-0 items-center gap-1 overflow-hidden text-ellipsis whitespace-nowrap text-sm leading-5 text-n-slate-11"
          :class="messagePreviewClass"
        >
          <Icon icon="i-lucide-info" class="size-3.5 shrink-0" />
          <span class="mx-0.5">
            {{ $t(`CHAT_LIST.NO_MESSAGES`) }}
          </span>
        </p>
      </div>

      <div class="grid w-40 shrink-0 gap-2 text-xs text-fd-muted" @click.stop>
        <label class="grid gap-1">
          <span class="sr-only">{{
            $t('CHAT_LIST.FRESHDESK_CARD.PRIORITY')
          }}</span>
          <span
            class="inline-flex items-center gap-1.5 font-medium text-fd-text"
          >
            <span class="size-2 rounded-full" :class="priorityDotClass" />
            {{ priorityLabel }}
          </span>
          <select
            class="h-8 rounded-lg border border-fd-border bg-fd-surface px-2 text-xs text-fd-text outline-none focus:border-fd-primary"
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

        <label class="grid gap-1">
          <span
            class="inline-flex min-w-0 items-center gap-1 font-medium text-fd-text"
          >
            <Icon
              :icon="
                isAgentBotAssignee ? 'i-lucide-bot' : 'i-lucide-user-round'
              "
              class="size-3.5 shrink-0"
            />
            <span class="truncate">{{ assigneeLabel }}</span>
          </span>
          <select
            class="h-8 rounded-lg border border-fd-border bg-fd-surface px-2 text-xs text-fd-text outline-none focus:border-fd-primary"
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

        <label class="grid gap-1">
          <span class="sr-only">
            {{ $t('CHAT_LIST.FRESHDESK_CARD.STATUS_LABEL') }}
          </span>
          <select
            class="h-8 rounded-lg border border-fd-border bg-fd-surface px-2 text-xs font-medium text-fd-text outline-none focus:border-fd-primary"
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
