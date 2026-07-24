<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Icon from 'dashboard/components-next/icon/Icon.vue';

defineProps({
  activeStatus: { type: String, required: true },
  activeAssigneeTab: { type: String, required: true },
  assigneeTabItems: { type: Array, default: () => [] },
  appliedFilterCount: { type: Number, default: 0 },
});

const emit = defineEmits(['changeStatus', 'changeAssignee', 'openFilters']);

const { t } = useI18n();

// Chatwoot has no separate "Closed" status — Freshdesk's terminal state maps
// onto Chatwoot's `resolved` (labelled "Closed" here).
const statusItems = computed(() => [
  {
    key: 'all',
    label: t('CHAT_LIST.FRESHDESK_PANEL.STATUS.all'),
    dot: 'bg-n-slate-8',
  },
  {
    key: 'open',
    label: t('CHAT_LIST.FRESHDESK_PANEL.STATUS.open'),
    dot: 'bg-fd-blue',
  },
  {
    key: 'pending',
    label: t('CHAT_LIST.FRESHDESK_PANEL.STATUS.pending'),
    dot: 'bg-fd-amber',
  },
  {
    key: 'resolved',
    label: t('CHAT_LIST.FRESHDESK_PANEL.STATUS.resolved'),
    dot: 'bg-fd-green',
  },
  {
    key: 'snoozed',
    label: t('CHAT_LIST.FRESHDESK_PANEL.STATUS.snoozed'),
    dot: 'bg-n-slate-8',
  },
]);

const rowClass = active =>
  active
    ? 'bg-fd-primary/10 font-semibold text-fd-primary'
    : 'text-fd-text hover:bg-fd-background';
</script>

<template>
  <aside
    class="flex w-60 shrink-0 flex-col gap-5 overflow-y-auto border-l border-fd-border bg-fd-surface p-3"
  >
    <div class="flex flex-col gap-1">
      <h3
        class="px-2 pb-1 text-xxs font-semibold uppercase tracking-wide text-fd-muted"
      >
        {{ t('CHAT_LIST.FRESHDESK_PANEL.STATUS_HEADING') }}
      </h3>
      <button
        v-for="item in statusItems"
        :key="item.key"
        type="button"
        class="flex items-center gap-2 rounded-lg px-2 py-1.5 text-left text-sm transition-colors"
        :class="rowClass(item.key === activeStatus)"
        @click="emit('changeStatus', item.key)"
      >
        <span class="size-2 shrink-0 rounded-full" :class="item.dot" />
        <span class="flex-1 truncate">{{ item.label }}</span>
      </button>
    </div>

    <div class="flex flex-col gap-1">
      <h3
        class="px-2 pb-1 text-xxs font-semibold uppercase tracking-wide text-fd-muted"
      >
        {{ t('CHAT_LIST.FRESHDESK_PANEL.ASSIGNEE_HEADING') }}
      </h3>
      <button
        v-for="item in assigneeTabItems"
        :key="item.key"
        type="button"
        class="flex items-center gap-2 rounded-lg px-2 py-1.5 text-left text-sm transition-colors"
        :class="rowClass(item.key === activeAssigneeTab)"
        @click="emit('changeAssignee', item.key)"
      >
        <span class="flex-1 truncate">{{ item.name }}</span>
        <span
          class="shrink-0 rounded-md bg-fd-background px-1.5 py-0.5 text-xxs font-medium text-fd-muted"
        >
          {{ item.count }}
        </span>
      </button>
    </div>

    <button
      type="button"
      class="mt-auto inline-flex items-center justify-center gap-2 rounded-lg border border-fd-border bg-fd-surface px-2 py-2 text-sm font-medium text-fd-text hover:border-fd-primary hover:text-fd-primary"
      @click="emit('openFilters')"
    >
      <Icon icon="i-lucide-list-filter" class="size-4" />
      {{ t('CHAT_LIST.FRESHDESK_PANEL.MORE_FILTERS') }}
      <span
        v-if="appliedFilterCount"
        class="rounded-md bg-fd-primary px-1.5 py-0.5 text-xxs font-semibold text-white"
      >
        {{ appliedFilterCount }}
      </span>
    </button>
  </aside>
</template>
