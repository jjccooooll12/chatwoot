<script setup>
import { computed, onMounted, reactive, ref, watch } from 'vue';
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

// Every property is edited as a draft and only persisted by the Update button
// (Freshdesk behaviour). Order number is the one exception: it also saves on
// blur. `saved` is what the conversation currently holds; each draft field
// follows its saved value whenever that changes (a save landing, another
// agent editing), without clobbering unsaved edits to the other fields.
const saved = computed(() => {
  const attrs = props.chat?.custom_attributes || {};
  return {
    type: attrs.freshdesk_type || '',
    followUp: attrs.freshdesk_auto_follow_up === 'yes' ? 'yes' : 'no',
    orderNumber: attrs.freshdesk_order_number || '',
    priority: props.chat?.priority || 'low',
    status: props.chat?.status || '',
    teamId: String(props.chat?.meta?.team?.id || 0),
    agentId: String(props.chat?.meta?.assignee?.id || ''),
  };
});

const FIELDS = [
  'type',
  'followUp',
  'orderNumber',
  'priority',
  'status',
  'teamId',
  'agentId',
];
const CUSTOM_ATTRIBUTE_FIELDS = ['type', 'followUp', 'orderNumber'];

const draft = reactive({ ...saved.value });

const resetDraft = () => Object.assign(draft, saved.value);

FIELDS.forEach(field => {
  watch(
    () => saved.value[field],
    value => {
      draft[field] = value;
    }
  );
});
watch(() => props.chat.id, resetDraft);

const isDirty = field => draft[field] !== saved.value[field];

// Auto follow-up needs a priority to drive its reopen timer. The panel shows
// Low when none is set, so persist that Low explicitly when follow-up is
// being switched on.
const priorityNeedsSave = computed(
  () =>
    isDirty('priority') ||
    (isDirty('followUp') && draft.followUp === 'yes' && !props.chat.priority)
);

const hasUnsavedChanges = computed(
  () => FIELDS.some(isDirty) || priorityNeedsSave.value
);

const updateButtonClass = computed(() => {
  if (justSaved.value) return 'bg-fd-green text-white';
  if (isSaving.value) return 'cursor-wait bg-fd-primary text-white opacity-70';
  if (hasUnsavedChanges.value) return 'cursor-pointer bg-fd-primary text-white';
  return 'cursor-default bg-fd-border text-fd-muted';
});

const saveCustomAttributes = values =>
  store.dispatch('updateCustomAttributes', {
    conversationId: props.chat.id,
    customAttributes: {
      ...(props.chat.custom_attributes || {}),
      freshdesk_type: values.type,
      freshdesk_auto_follow_up: values.followUp,
      freshdesk_order_number: values.orderNumber,
    },
  });

const assignAgent = agentIdValue => {
  const selected = assignableAgents.value.find(
    agent => String(agent.id ?? '') === agentIdValue
  );
  return store.dispatch('assignAgent', {
    conversationId: props.chat.id,
    agentId: selected?.id || null,
    assigneeType: selected?.assignee_type || 'User',
  });
};

const flashSaved = () => {
  // Brief color flash as a CSS-only "saved" confirmation on the Update
  // button — justSaved flips true then back false, and the button's own
  // transition-colors does the fading.
  justSaved.value = true;
  setTimeout(() => {
    justSaved.value = false;
  }, 700);
};

// The store actions swallow API errors and only commit on success, so a
// failed save simply leaves that field dirty and the button still lit.
const saveChanges = async () => {
  if (!hasUnsavedChanges.value) return;
  const conversationId = props.chat.id;
  const requests = [];

  if (CUSTOM_ATTRIBUTE_FIELDS.some(isDirty)) {
    requests.push(saveCustomAttributes(draft));
  }
  if (priorityNeedsSave.value) {
    requests.push(
      store.dispatch('assignPriority', {
        conversationId,
        priority: draft.priority,
      })
    );
  }
  if (isDirty('status')) {
    requests.push(
      store.dispatch('toggleStatus', {
        conversationId,
        status: draft.status,
        snoozedUntil: null,
      })
    );
  }
  if (isDirty('teamId')) {
    requests.push(
      store.dispatch('assignTeam', {
        conversationId,
        teamId: Number(draft.teamId || 0),
      })
    );
  }
  if (isDirty('agentId')) requests.push(assignAgent(draft.agentId));

  isSaving.value = true;
  await Promise.allSettled(requests);
  isSaving.value = false;
  flashSaved();
};

// Order number persists as soon as the agent leaves the field. Only that
// field is written — other pending edits stay pending for the Update button.
const onOrderNumberBlur = async () => {
  if (!isDirty('orderNumber')) return;
  await saveCustomAttributes({
    ...saved.value,
    orderNumber: draft.orderNumber,
  });
};

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
            v-model="draft.type"
            :options="typeOptions"
          />
        </div>

        <div class="grid gap-1.5">
          <span class="font-medium text-fd-text">
            {{ t('CHAT_LIST.FRESHDESK_DETAIL.AUTO_FOLLOW_UP') }}
          </span>
          <FreshdeskPropertySelect
            v-model="draft.followUp"
            :options="followUpOptions"
          />
        </div>

        <div class="grid gap-1.5">
          <span class="font-medium text-fd-text">
            {{ t('CHAT_LIST.FRESHDESK_DETAIL.PRIORITY') }}
          </span>
          <FreshdeskPropertySelect
            v-model="draft.priority"
            :options="priorityOptions"
          />
        </div>

        <div class="grid gap-1.5">
          <span class="font-medium text-fd-text">
            {{ t('CHAT_LIST.FRESHDESK_DETAIL.STATUS') }}
          </span>
          <FreshdeskPropertySelect
            v-model="draft.status"
            :options="statusOptions"
          />
        </div>

        <div class="grid gap-1.5">
          <span class="font-medium text-fd-text">
            {{ t('CHAT_LIST.FRESHDESK_DETAIL.GROUP') }}
          </span>
          <FreshdeskPropertySelect
            v-model="draft.teamId"
            :options="teamOptions"
          />
        </div>

        <div class="grid gap-1.5">
          <span class="font-medium text-fd-text">
            {{ t('CHAT_LIST.FRESHDESK_DETAIL.AGENT') }}
          </span>
          <FreshdeskPropertySelect
            v-model="draft.agentId"
            :options="agentOptions"
          />
        </div>

        <label class="grid gap-1.5">
          <span class="font-medium text-fd-text">
            {{ t('CHAT_LIST.FRESHDESK_DETAIL.ORDER_NUMBER') }}
          </span>
          <input
            v-model="draft.orderNumber"
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
        class="flex h-7 w-full items-center justify-center rounded-md px-3 text-xs font-semibold transition-colors duration-700"
        :class="updateButtonClass"
        :disabled="isSaving || !hasUnsavedChanges"
        @click="saveChanges"
      >
        {{ t('CHAT_LIST.FRESHDESK_DETAIL.UPDATE') }}
      </button>
    </div>
  </aside>
</template>
