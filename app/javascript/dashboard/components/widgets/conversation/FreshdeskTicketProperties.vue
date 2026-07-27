<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import wootConstants from 'dashboard/constants/globals';
import { shortenAgentName } from 'shared/helpers/agentNameHelper';

const props = defineProps({
  chat: {
    type: Object,
    required: true,
  },
});

const { t } = useI18n();
const store = useStore();

const customType = ref('');
const autoFollowUp = ref('no');
const orderNumber = ref('');
const lastSavedOrderNumber = ref('');
const isSaving = ref(false);
const priorityOpen = ref(false);

// Priority only applies when auto follow-up is on; each level drives the
// auto-reopen window handled server-side (low 5d / medium 3d / high 48h /
// urgent 24h). Colored squares mirror the Freshdesk palette.
const priorityKeys = ['low', 'medium', 'high', 'urgent'];
const priorityMeta = computed(() => ({
  low: { label: t('CONVERSATION.PRIORITY.OPTIONS.LOW'), dot: 'bg-n-teal-9' },
  medium: {
    label: t('CONVERSATION.PRIORITY.OPTIONS.MEDIUM'),
    dot: 'bg-n-blue-9',
  },
  high: { label: t('CONVERSATION.PRIORITY.OPTIONS.HIGH'), dot: 'bg-n-amber-9' },
  urgent: {
    label: t('CONVERSATION.PRIORITY.OPTIONS.URGENT'),
    dot: 'bg-n-ruby-9',
  },
}));
const currentPriority = computed(() => props.chat.priority || 'low');
const priorityDotClass = key => [
  'size-2.5 shrink-0 rounded-sm',
  priorityMeta.value[key]?.dot,
];

const statusOptions = computed(() => [
  { key: wootConstants.STATUS_TYPE.OPEN, label: 'Open' },
  { key: wootConstants.STATUS_TYPE.PENDING, label: 'Pending' },
  { key: wootConstants.STATUS_TYPE.RESOLVED, label: 'Closed' },
]);

const typeOptions = [
  { key: '', label: '--' },
  { key: 'question', label: 'Question' },
  { key: 'lead', label: 'Lead' },
  { key: 'request', label: 'Request' },
];

const followUpOptions = [
  { key: 'no', label: 'No' },
  { key: 'yes', label: 'Yes' },
];

const teamOptions = computed(() => [
  { id: 0, name: t('TEAMS_SETTINGS.LIST.NONE') },
  ...store.getters['teams/getTeams'],
]);

const assignableAgents = computed(() => {
  const inboxId = props.chat?.inbox_id;
  const agents = inboxId
    ? store.getters['inboxAssignableAgents/getAssignableAgents'](inboxId)
    : [];
  return [
    {
      id: '',
      name: t('CHAT_LIST.FRESHDESK_CARD.UNASSIGNED'),
      assignee_type: 'User',
    },
    ...agents,
  ];
});

const assignedAgentId = computed(() =>
  String(props.chat?.meta?.assignee?.id || '')
);
const assignedTeamId = computed(() => String(props.chat?.meta?.team?.id || 0));

const syncCustomFields = () => {
  const customAttributes = props.chat?.custom_attributes || {};
  customType.value = customAttributes.freshdesk_type || '';
  autoFollowUp.value =
    customAttributes.freshdesk_auto_follow_up === 'yes' ? 'yes' : 'no';
  orderNumber.value = customAttributes.freshdesk_order_number || '';
  lastSavedOrderNumber.value = orderNumber.value;
};

const updateStatus = event => {
  store.dispatch('toggleStatus', {
    conversationId: props.chat.id,
    status: event.target.value,
    snoozedUntil: null,
  });
  useAlert(t('CONVERSATION.CHANGE_STATUS'));
};

const selectPriority = key => {
  store.dispatch('assignPriority', {
    conversationId: props.chat.id,
    priority: key,
  });
  priorityOpen.value = false;
};

const updateAssignee = event => {
  const selected = assignableAgents.value.find(
    agent => String(agent.id ?? '') === event.target.value
  );
  const agentId = selected?.id || null;
  const assigneeType = selected?.assignee_type || 'User';
  store.dispatch('assignAgent', {
    conversationId: props.chat.id,
    agentId,
    assigneeType,
  });
};

const updateTeam = event => {
  store.dispatch('assignTeam', {
    conversationId: props.chat.id,
    teamId: Number(event.target.value || 0),
  });
};

const saveCustomFields = async () => {
  isSaving.value = true;
  await store.dispatch('updateCustomAttributes', {
    conversationId: props.chat.id,
    customAttributes: {
      freshdesk_type: customType.value,
      freshdesk_auto_follow_up: autoFollowUp.value,
      freshdesk_order_number: orderNumber.value,
    },
  });
  isSaving.value = false;
  useAlert(t('CONVERSATION_CUSTOM_ATTRIBUTES.UPDATE.SUCCESS'));
};

// Order number persists as soon as the agent leaves the field — no need to hit
// the Update button for this one.
const onOrderNumberBlur = async () => {
  if (orderNumber.value === lastSavedOrderNumber.value) return;
  lastSavedOrderNumber.value = orderNumber.value;
  await saveCustomFields();
};

// Turning follow-up on requires a priority (it drives the reopen timer); default
// to Low if none is set yet. Persist immediately so the server-side job sees it.
const onFollowUpChange = async () => {
  if (autoFollowUp.value === 'yes' && !props.chat.priority) {
    store.dispatch('assignPriority', {
      conversationId: props.chat.id,
      priority: 'low',
    });
  }
  await saveCustomFields();
};

watch(() => props.chat.id, syncCustomFields, { immediate: true });
watch(() => props.chat.custom_attributes, syncCustomFields, { deep: true });

onMounted(() => {
  if (props.chat?.inbox_id) {
    store.dispatch('inboxAssignableAgents/fetch', {
      inboxIds: [props.chat.inbox_id],
      includeAgentBots: true,
    });
  }
  store.dispatch('teams/get');
});
</script>

<template>
  <aside
    class="hidden w-[248px] shrink-0 overflow-y-auto border-l border-fd-border bg-fd-surface lg:block"
  >
    <div class="grid gap-2.5 px-3 py-4 text-xs">
      <h3 class="m-0 text-xxs font-semibold uppercase text-fd-muted">
        {{ t('CHAT_LIST.FRESHDESK_DETAIL.PROPERTIES') }}
      </h3>

      <label class="grid gap-1.5">
        <span class="font-medium text-fd-text">
          {{ t('CHAT_LIST.FRESHDESK_DETAIL.TYPE') }}
        </span>
        <select
          v-model="customType"
          class="h-8 rounded-md border border-fd-border bg-fd-surface px-2 text-xs text-fd-text outline-none focus:border-fd-primary"
        >
          <option
            v-for="option in typeOptions"
            :key="option.key"
            :value="option.key"
          >
            {{ option.label }}
          </option>
        </select>
      </label>

      <label class="grid gap-1.5">
        <span class="font-medium text-fd-text">
          {{ t('CHAT_LIST.FRESHDESK_DETAIL.AUTO_FOLLOW_UP') }}
        </span>
        <select
          v-model="autoFollowUp"
          class="h-8 rounded-md border border-fd-border bg-fd-surface px-2 text-xs text-fd-text outline-none focus:border-fd-primary"
          @change="onFollowUpChange"
        >
          <option
            v-for="option in followUpOptions"
            :key="option.key"
            :value="option.key"
          >
            {{ option.label }}
          </option>
        </select>
      </label>

      <div class="grid gap-1.5">
        <span class="font-medium text-fd-text">
          {{ t('CHAT_LIST.FRESHDESK_DETAIL.PRIORITY') }}
        </span>
        <div class="relative">
          <button
            type="button"
            class="flex h-8 w-full items-center gap-2 rounded-md border border-fd-border bg-fd-surface px-2 text-xs text-fd-text outline-none focus:border-fd-primary"
            @click="priorityOpen = !priorityOpen"
          >
            <span :class="priorityDotClass(currentPriority)" />
            <span>{{ priorityMeta[currentPriority].label }}</span>
            <span
              class="i-lucide-chevron-down size-3.5 text-fd-muted ltr:ml-auto rtl:mr-auto"
            />
          </button>
          <template v-if="priorityOpen">
            <button
              type="button"
              tabindex="-1"
              class="fixed inset-0 z-40 cursor-default"
              @click="priorityOpen = false"
            />
            <ul
              class="absolute inset-x-0 top-9 z-50 m-0 list-none rounded-md border border-fd-border bg-fd-surface p-1 shadow-lg"
            >
              <li v-for="key in priorityKeys" :key="key">
                <button
                  type="button"
                  class="flex w-full items-center gap-2 rounded px-2 py-1.5 text-left text-xs text-fd-text hover:bg-n-slate-3"
                  @click="selectPriority(key)"
                >
                  <span :class="priorityDotClass(key)" />
                  <span>{{ priorityMeta[key].label }}</span>
                </button>
              </li>
            </ul>
          </template>
        </div>
      </div>

      <label class="grid gap-1.5">
        <span class="font-medium text-fd-text">
          {{ t('CHAT_LIST.FRESHDESK_DETAIL.STATUS') }}
        </span>
        <select
          class="h-8 rounded-md border border-fd-border bg-fd-surface px-2 text-xs text-fd-text outline-none focus:border-fd-primary"
          :value="chat.status"
          @change="updateStatus"
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

      <label class="grid gap-1.5">
        <span class="font-medium text-fd-text">
          {{ t('CHAT_LIST.FRESHDESK_DETAIL.GROUP') }}
        </span>
        <select
          class="h-8 rounded-md border border-fd-border bg-fd-surface px-2 text-xs text-fd-text outline-none focus:border-fd-primary"
          :value="assignedTeamId"
          @change="updateTeam"
        >
          <option v-for="team in teamOptions" :key="team.id" :value="team.id">
            {{ team.name }}
          </option>
        </select>
      </label>

      <label class="grid gap-1.5">
        <span class="font-medium text-fd-text">
          {{ t('CHAT_LIST.FRESHDESK_DETAIL.AGENT') }}
        </span>
        <select
          class="h-8 rounded-md border border-fd-border bg-fd-surface px-2 text-xs text-fd-text outline-none focus:border-fd-primary"
          :value="assignedAgentId"
          @change="updateAssignee"
        >
          <option
            v-for="agent in assignableAgents"
            :key="agent.id || 'none'"
            :value="agent.id || ''"
          >
            {{ agent.id ? shortenAgentName(agent.name) : agent.name }}
          </option>
        </select>
      </label>

      <label class="grid gap-1.5">
        <span class="font-medium text-fd-text">
          {{ t('CHAT_LIST.FRESHDESK_DETAIL.ORDER_NUMBER') }}
        </span>
        <input
          v-model="orderNumber"
          type="text"
          :placeholder="
            t('CHAT_LIST.FRESHDESK_DETAIL.ORDER_NUMBER_PLACEHOLDER')
          "
          class="h-8 rounded-md border border-fd-border bg-fd-surface px-2 text-xs text-fd-text outline-none focus:border-fd-primary"
          @blur="onOrderNumberBlur"
          @keyup.enter="$event.target.blur()"
        />
      </label>

      <button
        type="button"
        class="sticky bottom-0 z-10 mt-2 h-9 rounded-md border-t border-fd-border bg-fd-primary px-3 text-sm font-semibold text-white shadow-[0_-4px_8px_-4px_rgba(0,0,0,0.15)] disabled:cursor-wait disabled:opacity-70"
        :disabled="isSaving"
        @click="saveCustomFields"
      >
        {{ t('CHAT_LIST.FRESHDESK_DETAIL.UPDATE') }}
      </button>
    </div>
  </aside>
</template>
