<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import wootConstants from 'dashboard/constants/globals';
import { shortenAgentName } from 'shared/helpers/agentNameHelper';
import FreshdeskPropertySelect from './FreshdeskPropertySelect.vue';

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
const justSaved = ref(false);

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
const priorityOptions = computed(() =>
  priorityKeys.map(key => ({
    value: key,
    label: priorityMeta.value[key].label,
    dotClass: priorityMeta.value[key].dot,
  }))
);

const statusOptions = [
  { value: wootConstants.STATUS_TYPE.OPEN, label: 'Open' },
  { value: wootConstants.STATUS_TYPE.PENDING, label: 'Pending' },
  { value: wootConstants.STATUS_TYPE.RESOLVED, label: 'Closed' },
];

const typeOptions = [
  { value: '', label: '--' },
  { value: 'question', label: 'Question' },
  { value: 'lead', label: 'Lead' },
  { value: 'request', label: 'Request' },
];

const followUpOptions = [
  { value: 'no', label: 'No' },
  { value: 'yes', label: 'Yes' },
];

const teamOptions = computed(() =>
  [
    { id: 0, name: t('TEAMS_SETTINGS.LIST.NONE') },
    ...store.getters['teams/getTeams'],
  ].map(team => ({ value: String(team.id), label: team.name }))
);

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

const agentOptions = computed(() =>
  assignableAgents.value.map(agent => ({
    value: String(agent.id || ''),
    label: agent.id ? shortenAgentName(agent.name) : agent.name,
  }))
);

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

const updateStatus = status => {
  store.dispatch('toggleStatus', {
    conversationId: props.chat.id,
    status,
    snoozedUntil: null,
  });
};

const selectPriority = key => {
  store.dispatch('assignPriority', {
    conversationId: props.chat.id,
    priority: key,
  });
};

const updateAssignee = agentIdValue => {
  const selected = assignableAgents.value.find(
    agent => String(agent.id ?? '') === agentIdValue
  );
  const agentId = selected?.id || null;
  const assigneeType = selected?.assignee_type || 'User';
  store.dispatch('assignAgent', {
    conversationId: props.chat.id,
    agentId,
    assigneeType,
  });
};

const updateTeam = teamId => {
  store.dispatch('assignTeam', {
    conversationId: props.chat.id,
    teamId: Number(teamId || 0),
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
  // Brief color flash as a CSS-only "saved" confirmation on the Update
  // button — justSaved flips true then back false, and the button's own
  // transition-colors does the fading.
  justSaved.value = true;
  setTimeout(() => {
    justSaved.value = false;
  }, 700);
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
const onFollowUpChange = async value => {
  autoFollowUp.value = value;
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
    class="hidden w-[220px] shrink-0 flex-col border-l border-fd-border bg-fd-surface lg:flex"
  >
    <div class="flex-1 overflow-y-auto">
      <div class="grid gap-1.5 px-3 pb-4 pt-4 text-xs">
        <h3 class="m-0 text-xxs font-semibold uppercase text-fd-muted">
          {{ t('CHAT_LIST.FRESHDESK_DETAIL.PROPERTIES') }}
        </h3>

        <div class="grid gap-1.5">
          <span class="font-medium text-fd-text">
            {{ t('CHAT_LIST.FRESHDESK_DETAIL.TYPE') }}
          </span>
          <FreshdeskPropertySelect
            v-model="customType"
            :options="typeOptions"
          />
        </div>

        <div class="grid gap-1.5">
          <span class="font-medium text-fd-text">
            {{ t('CHAT_LIST.FRESHDESK_DETAIL.AUTO_FOLLOW_UP') }}
          </span>
          <FreshdeskPropertySelect
            :model-value="autoFollowUp"
            :options="followUpOptions"
            @update:model-value="onFollowUpChange"
          />
        </div>

        <div class="grid gap-1.5">
          <span class="font-medium text-fd-text">
            {{ t('CHAT_LIST.FRESHDESK_DETAIL.PRIORITY') }}
          </span>
          <FreshdeskPropertySelect
            :model-value="currentPriority"
            :options="priorityOptions"
            @update:model-value="selectPriority"
          />
        </div>

        <div class="grid gap-1.5">
          <span class="font-medium text-fd-text">
            {{ t('CHAT_LIST.FRESHDESK_DETAIL.STATUS') }}
          </span>
          <FreshdeskPropertySelect
            :model-value="chat.status"
            :options="statusOptions"
            @update:model-value="updateStatus"
          />
        </div>

        <div class="grid gap-1.5">
          <span class="font-medium text-fd-text">
            {{ t('CHAT_LIST.FRESHDESK_DETAIL.GROUP') }}
          </span>
          <FreshdeskPropertySelect
            :model-value="assignedTeamId"
            :options="teamOptions"
            @update:model-value="updateTeam"
          />
        </div>

        <div class="grid gap-1.5">
          <span class="font-medium text-fd-text">
            {{ t('CHAT_LIST.FRESHDESK_DETAIL.AGENT') }}
          </span>
          <FreshdeskPropertySelect
            :model-value="assignedAgentId"
            :options="agentOptions"
            @update:model-value="updateAssignee"
          />
        </div>

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
            class="h-8 rounded-md border border-fd-primary/40 bg-fd-surface px-2 text-xs text-fd-text outline-none focus:border-fd-primary"
            @blur="onOrderNumberBlur"
            @keyup.enter="$event.target.blur()"
          />
        </label>
      </div>
    </div>

    <div class="shrink-0 border-t border-fd-border px-3 py-2.5">
      <button
        type="button"
        class="flex h-7 w-full items-center justify-center rounded-md px-3 text-xs font-semibold text-white transition-colors duration-700 disabled:cursor-wait disabled:opacity-70"
        :class="justSaved ? 'bg-fd-green' : 'bg-fd-primary'"
        :disabled="isSaving"
        @click="saveCustomFields"
      >
        {{ t('CHAT_LIST.FRESHDESK_DETAIL.UPDATE') }}
      </button>
    </div>
  </aside>
</template>
