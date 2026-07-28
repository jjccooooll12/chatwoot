<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import FreshdeskFilterPills from './FreshdeskFilterPills.vue';
import { useUISettings } from 'dashboard/composables/useUISettings';

const props = defineProps({
  activeStatuses: { type: Array, required: true },
  activeAssigneeTypes: { type: Array, required: true },
  assigneeTabItems: { type: Array, default: () => [] },
  activeChatLanguage: { type: String, default: '' },
  chatLanguageItems: { type: Array, default: () => [] },
  appliedFilterCount: { type: Number, default: 0 },
});

const emit = defineEmits([
  'toggleStatus',
  'toggleAssignee',
  'changeChatLanguage',
  'openFilters',
]);

const { t } = useI18n();
const { uiSettings, updateUISettings } = useUISettings();

// Chatwoot has no separate "Closed" status — Freshdesk's terminal state maps
// onto Chatwoot's `resolved` (labelled "Closed" here). No "All" pill: with
// multi-select, combining every status IS "all", so a separate option would
// be redundant.
// Same mapping as the status dot/pill on the ticket card (ConversationCard.vue):
// open = green (active work), pending = amber (waiting), closed = red.
const statusItems = computed(() => [
  {
    key: 'open',
    label: t('CHAT_LIST.FRESHDESK_PANEL.STATUS.open'),
    dot: 'bg-fd-green',
  },
  {
    key: 'pending',
    label: t('CHAT_LIST.FRESHDESK_PANEL.STATUS.pending'),
    dot: 'bg-fd-amber',
  },
  {
    key: 'resolved',
    label: t('CHAT_LIST.FRESHDESK_PANEL.STATUS.resolved'),
    dot: 'bg-fd-red',
  },
]);

const assigneeItems = computed(() =>
  props.assigneeTabItems.map(item => ({
    key: item.key,
    label: item.name,
    badge: item.count,
  }))
);

const rowClass = active =>
  active
    ? 'bg-fd-primary/10 font-semibold text-fd-primary'
    : 'text-fd-text hover:bg-fd-background';

// Per-agent preference for which of the 7 language buckets show up in the
// CHATS section — everyone sees all of them until they hide some themselves.
const visibleChatLanguageKeys = computed(() => {
  const stored = uiSettings.value?.visible_chat_languages;
  return Array.isArray(stored)
    ? stored
    : props.chatLanguageItems.map(item => item.key);
});

const visibleChatLanguageItems = computed(() =>
  props.chatLanguageItems.filter(item =>
    visibleChatLanguageKeys.value.includes(item.key)
  )
);

const languageSettingsOpen = ref(false);
const toggleLanguageVisibility = key => {
  const current = visibleChatLanguageKeys.value;
  const next = current.includes(key)
    ? current.filter(item => item !== key)
    : [...current, key];
  updateUISettings({ visible_chat_languages: next });
};
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
      <FreshdeskFilterPills
        :items="statusItems"
        :active-keys="activeStatuses"
        @toggle="key => emit('toggleStatus', key)"
      />
    </div>

    <div class="flex flex-col gap-1">
      <h3
        class="px-2 pb-1 text-xxs font-semibold uppercase tracking-wide text-fd-muted"
      >
        {{ t('CHAT_LIST.FRESHDESK_PANEL.ASSIGNEE_HEADING') }}
      </h3>
      <FreshdeskFilterPills
        :items="assigneeItems"
        :active-keys="activeAssigneeTypes"
        @toggle="key => emit('toggleAssignee', key)"
      />
    </div>

    <div class="flex flex-col gap-1">
      <div class="flex items-center justify-between px-2 pb-1">
        <h3
          class="text-xxs font-semibold uppercase tracking-wide text-fd-muted"
        >
          {{ t('CHAT_LIST.FRESHDESK_PANEL.CHATS_HEADING') }}
        </h3>
        <div class="relative">
          <button
            type="button"
            class="grid size-5 shrink-0 place-content-center rounded text-fd-muted hover:bg-fd-background hover:text-fd-text"
            :title="t('CHAT_LIST.FRESHDESK_PANEL.CHAT_LANGUAGE_SETTINGS')"
            @click="languageSettingsOpen = !languageSettingsOpen"
          >
            <Icon icon="i-lucide-settings" class="size-3.5" />
          </button>
          <template v-if="languageSettingsOpen">
            <button
              type="button"
              tabindex="-1"
              class="fixed inset-0 z-40 cursor-default"
              @click="languageSettingsOpen = false"
            />
            <ul
              class="absolute right-0 top-6 z-50 m-0 w-48 list-none rounded-md border border-fd-border bg-fd-surface p-1 shadow-lg"
            >
              <li
                class="px-2 py-1 text-xxs font-semibold uppercase tracking-wide text-fd-muted"
              >
                {{ t('CHAT_LIST.FRESHDESK_PANEL.CHAT_LANGUAGE_SETTINGS') }}
              </li>
              <li v-for="item in chatLanguageItems" :key="item.key">
                <label
                  class="flex w-full cursor-pointer items-center gap-2 rounded px-2 py-1.5 text-xs text-fd-text hover:bg-n-slate-3"
                >
                  <input
                    type="checkbox"
                    class="size-3.5 shrink-0"
                    :checked="visibleChatLanguageKeys.includes(item.key)"
                    @change="toggleLanguageVisibility(item.key)"
                  />
                  <span>{{ item.flag }}</span>
                  <span class="flex-1 truncate">{{ item.name }}</span>
                </label>
              </li>
            </ul>
          </template>
        </div>
      </div>
      <p
        v-if="!visibleChatLanguageItems.length"
        class="px-2 text-xs text-fd-muted"
      >
        {{ t('CHAT_LIST.FRESHDESK_PANEL.NO_CHAT_LANGUAGES_VISIBLE') }}
      </p>
      <button
        v-for="item in visibleChatLanguageItems"
        :key="item.key"
        type="button"
        class="flex items-center gap-2 rounded-lg px-2 py-1.5 text-left text-sm transition-colors"
        :class="rowClass(item.key === activeChatLanguage)"
        @click="emit('changeChatLanguage', item.key)"
      >
        <span class="shrink-0">{{ item.flag }}</span>
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
