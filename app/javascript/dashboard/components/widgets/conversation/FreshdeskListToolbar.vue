<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';

const props = defineProps({
  allConversationsSelected: { type: Boolean, default: false },
  activeSortBy: { type: String, required: true },
  conversationCount: { type: Number, default: 0 },
  totalCount: { type: Number, default: 0 },
});

const emit = defineEmits(['selectAll', 'changeFilter']);

const { t } = useI18n();

const sortOpen = ref(false);

// Freshdesk splits sorting into a field (top section) + a direction (bottom
// section). Every field below supports both asc & desc (SORT_BY_TYPE), so the
// two selections always combine into a valid `<field>_<direction>` value.
const sortFields = computed(() => [
  {
    key: 'last_activity_at',
    label: t('CHAT_LIST.FRESHDESK_TOOLBAR.SORT_FIELD.LAST_ACTIVITY'),
  },
  {
    key: 'created_at',
    label: t('CHAT_LIST.FRESHDESK_TOOLBAR.SORT_FIELD.CREATED_AT'),
  },
  {
    key: 'priority',
    label: t('CHAT_LIST.FRESHDESK_TOOLBAR.SORT_FIELD.PRIORITY'),
  },
  {
    key: 'waiting_since',
    label: t('CHAT_LIST.FRESHDESK_TOOLBAR.SORT_FIELD.WAITING_SINCE'),
  },
]);

const sortDirections = computed(() => [
  { key: 'asc', label: t('CHAT_LIST.FRESHDESK_TOOLBAR.SORT_DIR.ASCENDING') },
  { key: 'desc', label: t('CHAT_LIST.FRESHDESK_TOOLBAR.SORT_DIR.DESCENDING') },
]);

const DIRECTION_RE = /_(asc|desc)$/;
const activeField = computed(() => {
  const base = props.activeSortBy.replace(DIRECTION_RE, '');
  return sortFields.value.some(field => field.key === base)
    ? base
    : 'last_activity_at';
});
const activeDirection = computed(
  () => props.activeSortBy.match(DIRECTION_RE)?.[1] || 'desc'
);
const activeFieldLabel = computed(
  () => sortFields.value.find(field => field.key === activeField.value)?.label
);

const applySort = value => {
  emit('changeFilter', value, 'sort');
  sortOpen.value = false;
};
const selectField = key => applySort(`${key}_${activeDirection.value}`);
const selectDirection = key => applySort(`${activeField.value}_${key}`);

const rangeLabel = computed(() => {
  if (!props.conversationCount) {
    return t('CHAT_LIST.FRESHDESK_TOOLBAR.EMPTY_RANGE');
  }

  return t('CHAT_LIST.FRESHDESK_TOOLBAR.RANGE', {
    start: 1,
    end: props.conversationCount,
    total: props.totalCount || props.conversationCount,
  });
});
</script>

<template>
  <div
    class="flex min-h-12 flex-wrap items-center justify-between gap-3 border-y border-fd-border bg-fd-background px-3 py-2"
  >
    <div class="flex min-w-0 flex-wrap items-center gap-2">
      <label
        class="inline-flex h-8 items-center gap-2 rounded-lg border border-fd-border bg-fd-surface px-2 text-xs font-medium text-fd-text"
      >
        <Checkbox
          :model-value="allConversationsSelected"
          @update:model-value="value => emit('selectAll', value)"
        />
        <span class="sr-only">
          {{ t('CHAT_LIST.FRESHDESK_TOOLBAR.SELECT_ALL') }}
        </span>
      </label>

      <div class="flex items-center gap-1.5">
        <span class="whitespace-nowrap text-xs text-fd-muted">
          {{ t('CHAT_LIST.FRESHDESK_TOOLBAR.SORT_BY') }}
        </span>
        <div class="relative">
          <button
            type="button"
            class="inline-flex h-8 items-center gap-1.5 rounded-lg border border-fd-border bg-fd-surface px-2.5 text-xs font-medium text-fd-text hover:border-fd-primary"
            @click="sortOpen = !sortOpen"
          >
            <span class="whitespace-nowrap">{{ activeFieldLabel }}</span>
            <span class="i-lucide-chevron-down size-3.5 text-fd-muted" />
          </button>
          <template v-if="sortOpen">
            <button
              type="button"
              tabindex="-1"
              class="fixed inset-0 z-40 cursor-default"
              @click="sortOpen = false"
            />
            <ul
              class="absolute left-0 top-9 z-50 m-0 w-52 list-none rounded-lg border border-fd-border bg-fd-surface p-1 shadow-lg"
            >
              <li v-for="field in sortFields" :key="field.key">
                <button
                  type="button"
                  class="flex w-full items-center justify-between gap-2 rounded-md px-2 py-1.5 text-left text-xs"
                  :class="
                    field.key === activeField
                      ? 'bg-fd-blueSoft font-medium text-fd-blue'
                      : 'text-fd-text hover:bg-n-slate-3'
                  "
                  @click="selectField(field.key)"
                >
                  <span>{{ field.label }}</span>
                  <span
                    v-if="field.key === activeField"
                    class="i-lucide-check size-3.5 shrink-0"
                  />
                </button>
              </li>
              <li class="my-1 border-t border-fd-border" role="separator" />
              <li v-for="dir in sortDirections" :key="dir.key">
                <button
                  type="button"
                  class="flex w-full items-center justify-between gap-2 rounded-md px-2 py-1.5 text-left text-xs"
                  :class="
                    dir.key === activeDirection
                      ? 'bg-fd-blueSoft font-medium text-fd-blue'
                      : 'text-fd-text hover:bg-n-slate-3'
                  "
                  @click="selectDirection(dir.key)"
                >
                  <span>{{ dir.label }}</span>
                  <span
                    v-if="dir.key === activeDirection"
                    class="i-lucide-check size-3.5 shrink-0"
                  />
                </button>
              </li>
            </ul>
          </template>
        </div>
      </div>
    </div>

    <span class="whitespace-nowrap text-xs font-medium text-fd-text">
      {{ rangeLabel }}
    </span>
  </div>
</template>
