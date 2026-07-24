<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import ConversationLabels from 'dashboard/routes/dashboard/conversation/labels/LabelBox.vue';
import SLACardLabel from './components/SLACardLabel.vue';
import wootConstants from 'dashboard/constants/globals';

const props = defineProps({
  chat: {
    type: Object,
    required: true,
  },
});

const { t } = useI18n();
const store = useStore();

const customType = ref('');
const autoFollowUp = ref('');
const isSaving = ref(false);

const currentContact = computed(() => {
  const senderId = props.chat?.meta?.sender?.id;
  return senderId ? store.getters['contacts/getContact'](senderId) : {};
});

const hasSlaPolicyId = computed(
  () => props.chat?.applied_sla?.id && !currentContact.value?.blocked
);

const priorityOptions = computed(() => [
  { key: '', label: t('CONVERSATION.PRIORITY.OPTIONS.NONE') },
  { key: 'low', label: t('CONVERSATION.PRIORITY.OPTIONS.LOW') },
  { key: 'medium', label: t('CONVERSATION.PRIORITY.OPTIONS.MEDIUM') },
  { key: 'high', label: t('CONVERSATION.PRIORITY.OPTIONS.HIGH') },
  { key: 'urgent', label: t('CONVERSATION.PRIORITY.OPTIONS.URGENT') },
]);

const statusOptions = computed(() => [
  { key: wootConstants.STATUS_TYPE.OPEN, label: 'Open' },
  { key: wootConstants.STATUS_TYPE.PENDING, label: 'Pending' },
  { key: wootConstants.STATUS_TYPE.RESOLVED, label: 'Closed' },
]);

const typeOptions = [
  { key: '', label: '--' },
  { key: 'question', label: 'Question' },
  { key: 'incident', label: 'Incident' },
  { key: 'problem', label: 'Problem' },
  { key: 'task', label: 'Task' },
];

const followUpOptions = [
  { key: '', label: '--' },
  { key: 'none', label: 'None' },
  { key: 'tomorrow', label: 'Tomorrow' },
  { key: 'next_week', label: 'Next week' },
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
  autoFollowUp.value = customAttributes.freshdesk_auto_follow_up || '';
};

const updateStatus = event => {
  store.dispatch('toggleStatus', {
    conversationId: props.chat.id,
    status: event.target.value,
    snoozedUntil: null,
  });
  useAlert(t('CONVERSATION.CHANGE_STATUS'));
};

const updatePriority = event => {
  store.dispatch('assignPriority', {
    conversationId: props.chat.id,
    priority: event.target.value || null,
  });
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
    },
  });
  isSaving.value = false;
  useAlert(t('CONVERSATION_CUSTOM_ATTRIBUTES.UPDATE.SUCCESS'));
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
    <div class="border-b border-fd-border px-3 py-5">
      <div class="flex items-center justify-between">
        <span class="text-base font-medium capitalize text-fd-text">
          {{ chat.status }}
        </span>
        <Icon icon="i-lucide-panel-right-close" class="size-4 text-fd-muted" />
      </div>
      <div class="mt-4 grid gap-3 text-xs text-fd-text">
        <div v-if="hasSlaPolicyId" class="grid gap-2">
          <SLACardLabel :chat="chat" show-extended-info />
        </div>
        <p v-else class="m-0 text-fd-muted">
          {{ t('CHAT_LIST.FRESHDESK_DETAIL.NO_ACTIVE_SLA') }}
        </p>
      </div>
    </div>

    <div class="grid gap-4 px-3 py-4 text-xs">
      <h3 class="m-0 text-xxs font-semibold uppercase text-fd-muted">
        {{ t('CHAT_LIST.FRESHDESK_DETAIL.PROPERTIES') }}
      </h3>

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
          {{ t('CHAT_LIST.FRESHDESK_DETAIL.TAGS') }}
        </span>
        <ConversationLabels :conversation-id="chat.id" />
      </label>

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

      <label class="grid gap-1.5">
        <span class="font-medium text-fd-text">
          {{ t('CHAT_LIST.FRESHDESK_DETAIL.PRIORITY') }}
        </span>
        <select
          class="h-8 rounded-md border border-fd-border bg-fd-surface px-2 text-xs text-fd-text outline-none focus:border-fd-primary"
          :value="chat.priority || ''"
          @change="updatePriority"
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
            {{ agent.name }}
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

      <button
        type="button"
        class="mt-2 h-9 rounded-md bg-fd-primary px-3 text-sm font-semibold text-white disabled:cursor-wait disabled:opacity-70"
        :disabled="isSaving"
        @click="saveCustomFields"
      >
        {{ t('CHAT_LIST.FRESHDESK_DETAIL.UPDATE') }}
      </button>
    </div>
  </aside>
</template>
