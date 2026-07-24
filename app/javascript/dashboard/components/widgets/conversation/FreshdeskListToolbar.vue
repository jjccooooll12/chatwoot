<script setup>
import { computed } from 'vue';
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

const sortOptions = computed(() => [
  {
    label: t('CHAT_LIST.SORT_ORDER_ITEMS.created_at_desc.TEXT'),
    value: 'created_at_desc',
  },
  {
    label: t('CHAT_LIST.SORT_ORDER_ITEMS.created_at_asc.TEXT'),
    value: 'created_at_asc',
  },
  {
    label: t('CHAT_LIST.SORT_ORDER_ITEMS.last_activity_at_desc.TEXT'),
    value: 'last_activity_at_desc',
  },
  {
    label: t('CHAT_LIST.SORT_ORDER_ITEMS.last_activity_at_asc.TEXT'),
    value: 'last_activity_at_asc',
  },
  {
    label: t('CHAT_LIST.SORT_ORDER_ITEMS.priority_desc.TEXT'),
    value: 'priority_desc',
  },
  {
    label: t('CHAT_LIST.SORT_ORDER_ITEMS.unread.TEXT'),
    value: 'unread',
  },
]);

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

      <label
        class="inline-flex h-8 items-center gap-2 rounded-lg border border-fd-border bg-fd-surface px-2 text-xs text-fd-muted"
      >
        <span class="whitespace-nowrap">
          {{ t('CHAT_LIST.FRESHDESK_TOOLBAR.SORT_BY') }}
        </span>
        <select
          class="h-7 max-w-44 bg-transparent text-xs font-medium text-fd-text outline-none"
          :value="activeSortBy"
          @change="event => emit('changeFilter', event.target.value, 'sort')"
        >
          <option
            v-for="option in sortOptions"
            :key="option.value"
            :value="option.value"
          >
            {{ option.label }}
          </option>
        </select>
      </label>
    </div>

    <span class="whitespace-nowrap text-xs font-medium text-fd-text">
      {{ rangeLabel }}
    </span>
  </div>
</template>
